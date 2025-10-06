const { getPool } = require('../shared/db');
const { checkApiKey } = require('../shared/auth');

//test
module.exports = async function (context, req) {
  try {
    checkApiKey(req);
    const id = parseInt(context.bindingData.id, 10);
    if (Number.isNaN(id)) return { status: 400, jsonBody: { error: 'Invalid id' } };

    const pool = await getPool();

    const patient = await pool.request().input('patient_id', id).query(`
      SELECT p.*, f.family_name
      FROM dementia_app.patients p
      JOIN dementia_app.families f ON f.family_id = p.family_id
      WHERE p.patient_id = @patient_id;
    `);
    if (patient.recordset.length === 0) return { status: 404, jsonBody: { error: 'Patient not found' } };

    const contacts = await pool.request().input('patient_id', id)
      .query('SELECT * FROM dementia_app.contacts WHERE patient_id = @patient_id ORDER BY contact_id;');

    const memories = await pool.request().input('patient_id', id).query(`
      SELECT memory_id, patient_id, memory_type, title, content_text, media_url, tags, created_at, updated_at
      FROM dementia_app.memories
      WHERE patient_id = @patient_id
      ORDER BY memory_id DESC;
    `);

    const agenda = await pool.request().input('patient_id', id).query(`
      SELECT agenda_id, title, details, start_time_utc, end_time_utc
      FROM dementia_app.agenda
      WHERE patient_id = @patient_id AND start_time_utc >= DATEADD(day, -7, SYSUTCDATETIME())
      ORDER BY start_time_utc;
    `);

    const reminders = await pool.request().input('patient_id', id).query(`
      SELECT reminder_id, title, message, remind_at_utc
      FROM dementia_app.reminders
      WHERE patient_id = @patient_id AND remind_at_utc >= DATEADD(day, -7, SYSUTCDATETIME())
      ORDER BY remind_at_utc;
    `);

    return {
      jsonBody: {
        patient: patient.recordset[0],
        contacts: contacts.recordset,
        memories: memories.recordset,
        agenda: agenda.recordset,
        reminders: reminders.recordset
      }
    };
  } catch (err) {
    const status = err.status || 500;
    return { status, jsonBody: { error: err.message || 'Server error' } };
  }
}
