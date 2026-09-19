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

  // Extract raw drive link from Column E (or matching header name)
  // Replaces exact Google Form response header name for Column E
  const rawImageLink = data['Hero Image'] || row[4] || ''; 
  const imageUrl = formatDriveUrl(rawImageLink);

  const payload = {
    name: data['Business Name'] || 'Unknown Business',
    category: data['Category'] || 'General',
    description: data['Short Pitch'] || '',
    host_tip: data['Insider Tip for Visitors'] || '',
    image_url: imageUrl // Added image_url field
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

// Converts Google Drive view links to direct image render links
function formatDriveUrl(url) {
  if (!url) return '';
  
  // Extract file ID using regex
  const match = url.match(/[-\w]{25,}/);
  if (match) {
    const fileId = match[0];
    
    // Ensure the uploaded file in Drive is publicly accessible
    try {
      DriveApp.getFileById(fileId).setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.VIEW);
    } catch(e) {
      Logger.log('Could not automatically update Drive permissions: ' + e.toString());
    }

    return `https://lh3.googleusercontent.com/d/${fileId}`;
  }
  return url;
}