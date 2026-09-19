// Cabin Concierge TV - Recommendations onboarding form handler
// Google Apps Script trigger: onFormSubmit (installable trigger on the Sheet
// that collects Google Form responses for new local-business recommendations).
//
// Why this differs from the original version: the original built a
// "https://lh3.googleusercontent.com/d/<fileId>" hotlink to the Drive file.
// That endpoint redirects to a Google-authenticated URL
// (work.fife.usercontent.google.com -> accounts.google.com/ServiceLogin) unless
// the file is shared in a way Google's own hotlink CDN accepts, which commonly
// fails under Workspace domain sharing policies. The Roku Poster component has
// no way to complete a Google sign-in redirect, so the image never loads.
//
// Fix: download the Drive file's bytes here (server-side, already authenticated
// as the script owner) and re-upload them to a dedicated PUBLIC Supabase Storage
// bucket ("recommendation-images"). The resulting Supabase public URL is a plain,
// stable, unauthenticated HTTPS link that Roku's Poster node can load directly.

function onFormSubmit(e) {
  const scriptProperties = PropertiesService.getScriptProperties();
  const SUPABASE_URL = scriptProperties.getProperty('SUPABASE_URL');
  const SUPABASE_SERVICE_KEY = scriptProperties.getProperty('SUPABASE_SERVICE_KEY');

  if (!SUPABASE_URL || !SUPABASE_SERVICE_KEY) {
    Logger.log('Error: Supabase URL or Service Key is missing from Script Properties.');
    return;
  }

  const sheet = SpreadsheetApp.getActiveSpreadsheet().getActiveSheet();
  const headers = sheet.getRange(1, 1, 1, sheet.getLastColumn()).getValues()[0];
  const row = e.values;

  let data = {};
  headers.forEach((header, index) => {
    data[header.trim()] = row[index];
  });

  const rawImageLink = data['Hero Image'] || row[4] || '';
  const imageUrl = uploadDriveImageToSupabase(rawImageLink, SUPABASE_URL, SUPABASE_SERVICE_KEY);

  const payload = {
    name: data['Business Name'] || 'Unknown Business',
    category: data['Category'] || 'General',
    description: data['Short Pitch'] || '',
    host_tip: data['Insider Tip for Visitors'] || '',
    address: data['Address'] || '',
    image_url: imageUrl
  };

  const options = {
    'method': 'post',
    'contentType': 'application/json',
    'headers': {
      'apikey': SUPABASE_SERVICE_KEY,
      'Authorization': 'Bearer ' + SUPABASE_SERVICE_KEY,
      'Prefer': 'return=minimal'
    },
    'payload': JSON.stringify(payload)
  };

  try {
    const response = UrlFetchApp.fetch(`${SUPABASE_URL}/rest/v1/recommendations`, options);
    Logger.log('Success: ' + response.getResponseCode());
  } catch (error) {
    Logger.log('Error: ' + error.toString());
  }
}

// Downloads the Drive file's bytes and re-hosts them in the public
// "recommendation-images" Supabase Storage bucket. Returns the public URL, or
// '' if there was no image link or the upload failed.
function uploadDriveImageToSupabase(driveUrl, SUPABASE_URL, SUPABASE_SERVICE_KEY) {
  if (!driveUrl) return '';

  const match = driveUrl.match(/[-\w]{25,}/);
  if (!match) return '';
  const fileId = match[0];

  let blob;
  try {
    blob = DriveApp.getFileById(fileId).getBlob();
  } catch (e) {
    Logger.log('Could not read Drive file ' + fileId + ': ' + e.toString());
    return '';
  }

  const contentType = blob.getContentType() || 'image/jpeg';
  const extension = (contentType.split('/')[1] || 'jpg').toLowerCase();
  const objectPath = `${fileId}.${extension}`;

  const uploadOptions = {
    'method': 'post',
    'contentType': contentType,
    'headers': {
      'apikey': SUPABASE_SERVICE_KEY,
      'Authorization': 'Bearer ' + SUPABASE_SERVICE_KEY,
      'x-upsert': 'true'
    },
    'payload': blob.getBytes(),
    'muteHttpExceptions': true
  };

  const uploadUrl = `${SUPABASE_URL}/storage/v1/object/recommendation-images/${objectPath}`;
  const response = UrlFetchApp.fetch(uploadUrl, uploadOptions);

  if (response.getResponseCode() >= 300) {
    Logger.log('Supabase Storage upload failed (' + response.getResponseCode() + '): ' + response.getContentText());
    return '';
  }

  return `${SUPABASE_URL}/storage/v1/object/public/recommendation-images/${objectPath}`;
}
