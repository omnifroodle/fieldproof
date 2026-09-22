// Runs inside Capella App Services on every write to evidence.reports.
// Talking point: one small JavaScript function decides who can see and write each document.
function (doc, oldDoc, meta) {
  if (doc._deleted) { return; }                       // tombstones keep the old channel
  if (!doc.district) { throw({ forbidden: "district is required" }); }
  if (doc.type !== "report") { throw({ forbidden: "wrong type for reports collection" }); }
  if (oldDoc && oldDoc.district !== doc.district) {
    throw({ forbidden: "district cannot change" });
  }
  var ch = "district." + doc.district;
  requireAccess(ch);   // the writing user must already have access to that district
  channel(ch);         // route the document to that district's channel
}
