const { getPool } = require('../shared/db');
const { checkApiKey } = require('../shared/auth');

module.exports = async function (context, req) {
  try {
    checkApiKey(req);
    const id = parseInt(context.bindingData.id, 10);
    if (Number.isNaN(id)) return { status: 400, jsonBody: { error: 'Invalid id' } };

    const pool = await getPool();
    const family = await pool.request().input('family_id', id).query(`
      SELECT family_id, family_name, notes, created_at, updated_at
      FROM dementia_app.families WHERE family_id = @family_id;
    `);
    if (family.recordset.length === 0) return { status: 404, jsonBody: { error: 'Family not found' } };

    const patients = await pool.request().input('family_id', id).query(`
      SELECT patient_id, family_id, first_name, last_name, date_of_birth, notes, created_at, updated_at
      FROM dementia_app.patients WHERE family_id = @family_id ORDER BY patient_id;
    `);

    const contacts = await pool.request().input('family_id', id).query(`
      SELECT contact_id, family_id, patient_id, relationship, display_name, email, phone, created_at, updated_at
      FROM dementia_app.contacts WHERE family_id = @family_id ORDER BY contact_id;
    `);

    return { jsonBody: { family: family.recordset[0], patients: patients.recordset, contacts: contacts.recordset } };
  } catch (err) {
    const status = err.status || 500;
    return { status, jsonBody: { error: err.message || 'Server error' } };
  }
}
