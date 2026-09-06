/*
 * Cabin Concierge Roku reservation sync for Google Apps Script.
 *
 * Required Script Properties:
 * TRACK_OPTIONS_JSON       JSON-serialized UrlFetchApp options for Track PMS.
 * SUPABASE_URL             https://<project-ref>.supabase.co
 * SUPABASE_SERVICE_ROLE_KEY Server-only key. Never place this in Roku manifest.
 *
 * The existing Roku sheet sync writes Track unit IDs to Supabase properties.id.
 */

const ROKU_RESERVATION_SYNC_DAYS = 90;
const TRACK_ARRIVAL_STATUSES = ["confirmed"];

function syncRokuReservations() {
  const config = getRokuReservationSyncConfig_();
  const today = new Date();
  const endDate = new Date(today);
  endDate.setDate(endDate.getDate() + ROKU_RESERVATION_SYNC_DAYS);

  const reservations = getTrackReservations_(
    formatTrackDate_(today),
    formatTrackDate_(endDate),
    config.trackOptions
  );
  const propertyIds = getSupabasePropertyIds_(config);
  const records = reservations
    .map(function (reservation) {
      return mapTrackReservation_(reservation, propertyIds);
    })
    .filter(function (record) {
      return record !== null;
    });

  upsertSupabaseReservations_(records, config);
  markMissingReservationsAsCancelled_(reservations, config);
  console.log("Roku reservation sync: " + records.length + " reservations imported.");
}

function getTrackReservations_(arrivalStart, arrivalEnd, trackOptions) {
  const baseUrl = "https://brokenbowvacationcabins.trackhs.com/api/pms/reservations";
  const seenReservationIds = {};
  const reservations = [];

  TRACK_ARRIVAL_STATUSES.forEach(function (status) {
    const url = baseUrl
      + "?sortColumn=checkin&sortDirection=asc"
      + "&arrivalStart=" + encodeURIComponent(arrivalStart)
      + "&arrivalEnd=" + encodeURIComponent(arrivalEnd)
      + "&scroll=1&size=100"
      + "&status=" + encodeURIComponent(status);
    appendUniqueTrackReservations_(url, trackOptions, seenReservationIds, reservations);
  });

  const inHouseUrl = baseUrl
    + "?sortColumn=name&sortDirection=asc&scroll=1&size=100"
    + "&inHouseToday=1&status=" + encodeURIComponent("Checked In");
  appendUniqueTrackReservations_(inHouseUrl, trackOptions, seenReservationIds, reservations);

  return reservations;
}

function getSupabasePropertyIds_(config) {
  const url = config.supabaseUrl + "/rest/v1/properties?select=id";
  const response = UrlFetchApp.fetch(url, {
    method: "get",
    headers: {
      apikey: config.supabaseServiceRoleKey,
      Authorization: "Bearer " + config.supabaseServiceRoleKey
    },
    muteHttpExceptions: true
  });

  if (response.getResponseCode() < 200 || response.getResponseCode() > 299) {
    throw new Error("Supabase property lookup failed (HTTP "
      + response.getResponseCode() + "): " + response.getContentText());
  }

  return JSON.parse(response.getContentText()).reduce(function (propertyIds, property) {
    propertyIds[String(property.id)] = true;
    return propertyIds;
  }, {});
}

function markMissingReservationsAsCancelled_(activeReservations, config) {
  const activePmsIds = {};
  activeReservations.forEach(function (reservation) {
    activePmsIds[String(reservation.id)] = true;
  });

  const cutoff = new Date();
  cutoff.setDate(cutoff.getDate() - 1);
  const cutoffIso = cutoff.toISOString();

  const url = config.supabaseUrl + "/rest/v1/reservations"
    + "?cancelled_at=is.null&check_out_at=gte." + encodeURIComponent(cutoffIso)
    + "&select=pms_reservation_id";
  const response = UrlFetchApp.fetch(url, {
    method: "get",
    headers: {
      apikey: config.supabaseServiceRoleKey,
      Authorization: "Bearer " + config.supabaseServiceRoleKey
    },
    muteHttpExceptions: true
  });

  if (response.getResponseCode() < 200 || response.getResponseCode() > 299) {
    throw new Error("Supabase active-reservation lookup failed (HTTP "
      + response.getResponseCode() + "): " + response.getContentText());
  }

  const rows = JSON.parse(response.getContentText());
  const toCancel = rows
    .filter(function (row) {
      return !activePmsIds[String(row.pms_reservation_id)];
    })
    .map(function (row) {
      return {
        pms_reservation_id: row.pms_reservation_id,
        cancelled_at: new Date().toISOString()
      };
    });

  if (toCancel.length > 0) {
    const patchUrl = config.supabaseUrl + "/rest/v1/reservations?pms_reservation_id=in.("
      + toCancel.map(function (row) { return row.pms_reservation_id; }).join(",") + ")";
    const patchResponse = UrlFetchApp.fetch(patchUrl, {
      method: "patch",
      contentType: "application/json",
      payload: JSON.stringify({ cancelled_at: new Date().toISOString() }),
      headers: {
        apikey: config.supabaseServiceRoleKey,
        Authorization: "Bearer " + config.supabaseServiceRoleKey,
        Prefer: "return=minimal"
      },
      muteHttpExceptions: true
    });

    if (patchResponse.getResponseCode() < 200 || patchResponse.getResponseCode() > 299) {
      throw new Error("Supabase cancellation update failed (HTTP "
        + patchResponse.getResponseCode() + "): " + patchResponse.getContentText());
    }

    console.log("Marked " + toCancel.length + " reservation(s) as cancelled: "
      + toCancel.map(function (row) { return row.pms_reservation_id; }).join(", "));
  }
}

function appendUniqueTrackReservations_(url, trackOptions, seenReservationIds, reservations) {
  const response = UrlFetchApp.fetch(url, trackOptions);
  const data = JSON.parse(response.getContentText());
  const items = data._embedded && data._embedded.reservations
    ? data._embedded.reservations
    : [];

  items.forEach(function (reservation) {
    const reservationId = String(reservation.id);
    if (!seenReservationIds[reservationId]) {
      seenReservationIds[reservationId] = true;
      reservations.push(reservation);
    }
  });
}

function mapTrackReservation_(reservation, propertyIds) {
  const propertyId = reservation.unitId === null || reservation.unitId === undefined
    ? ""
    : String(reservation.unitId);
  const contact = reservation._embedded && reservation._embedded.contact;
  const guestName = contact && contact.name ? String(contact.name).trim() : "";
  const isCancelled = reservation.cancelledAt !== null
    || String(reservation.status || "").toLowerCase() === "cancelled";

  if (!propertyId) {
    console.log("Skipping Track reservation " + reservation.id + ": missing unitId.");
    return null;
  }
  if (!propertyIds[propertyId]) {
    console.log("Skipping Track reservation " + reservation.id + ": Track unit " + propertyId
      + " has no matching Supabase properties.id. Run syncPropertiesToSupabase first.");
    return null;
  }
  if (!reservation.arrivalTime || !reservation.departureTime) {
    console.log("Skipping Track reservation " + reservation.id + ": missing arrivalTime or departureTime.");
    return null;
  }
  if (!guestName && !isCancelled) {
    console.log("Skipping Track reservation " + reservation.id + ": missing guest display name.");
    return null;
  }

  return {
    pms_reservation_id: String(reservation.id),
    property_id: propertyId,
    guest_display_name: guestName || "Cancelled reservation",
    check_in_at: reservation.arrivalTime,
    check_out_at: reservation.departureTime,
    cancelled_at: isCancelled ? (reservation.cancelledAt || new Date().toISOString()) : null
  };
}

function upsertSupabaseReservations_(records, config) {
  if (records.length === 0) return;

  const url = config.supabaseUrl + "/rest/v1/reservations?on_conflict=pms_reservation_id";
  const response = UrlFetchApp.fetch(url, {
    method: "post",
    contentType: "application/json",
    payload: JSON.stringify(records),
    headers: {
      apikey: config.supabaseServiceRoleKey,
      Authorization: "Bearer " + config.supabaseServiceRoleKey,
      Prefer: "resolution=merge-duplicates,return=minimal"
    },
    muteHttpExceptions: true
  });

  if (response.getResponseCode() < 200 || response.getResponseCode() > 299) {
    throw new Error("Supabase reservation upsert failed (HTTP "
      + response.getResponseCode() + "): " + response.getContentText());
  }
}

function getRokuReservationSyncConfig_() {
  const properties = PropertiesService.getScriptProperties();
  const trackOptionsJson = properties.getProperty("TRACK_OPTIONS_JSON");
  const supabaseUrl = properties.getProperty("SUPABASE_URL");
  const supabaseServiceRoleKey = properties.getProperty("SUPABASE_SERVICE_ROLE_KEY");

  if (!trackOptionsJson || !supabaseUrl || !supabaseServiceRoleKey) {
    throw new Error("Set TRACK_OPTIONS_JSON, SUPABASE_URL, and SUPABASE_SERVICE_ROLE_KEY in Script Properties.");
  }

  return {
    trackOptions: JSON.parse(trackOptionsJson),
    supabaseUrl: supabaseUrl.replace(/\/$/, ""),
    supabaseServiceRoleKey: supabaseServiceRoleKey
  };
}

function formatTrackDate_(date) {
  return Utilities.formatDate(date, "America/Chicago", "yyyy-MM-dd");
}