const { getPool } = require('../shared/db');
const { checkApiKey } = require('../shared/auth');

module.exports = async function (context, req) {
  try {
    checkApiKey(req);
    const id = parseInt(context.bindingData.id, 10);
    if (Number.isNaN(id)) return { status: 400, jsonBody: { error: 'Invalid id' } };

    const body = req.body || {};
    const family_name = body.family_name;
    const notes = Object.prototype.hasOwnProperty.call(body, 'notes') ? body.notes : undefined;
    if (!family_name && typeof notes === 'undefined') {
      return { status: 400, jsonBody: { error: 'Nothing to update' } };
    }

    const pool = await getPool();
    const sets = [];
    if (family_name) sets.push("family_name = @family_name");
    if (typeof notes !== 'undefined') sets.push("notes = @notes");
    sets.push("updated_at = SYSUTCDATETIME()");
    const setClause = sets.join(', ');

    const request = pool.request().input('family_id', id);
    if (family_name) request.input('family_name', family_name);
    if (typeof notes !== 'undefined') request.input('notes', notes);

    const result = await request.query(`
      UPDATE dementia_app.families
      SET ${setClause}
      WHERE family_id = @family_id;

      SELECT family_id, family_name, notes, created_at, updated_at
      FROM dementia_app.families WHERE family_id = @family_id;
    `);

    const rows = result.recordsets && result.recordsets[0] ? result.recordsets[0] : result.recordset;
    if (!rows || rows.length === 0) return { status: 404, jsonBody: { error: 'Family not found' } };
    return { jsonBody: rows[0] };
  } catch (err) {
    const status = err.status || 500;
    return { status, jsonBody: { error: err.message || 'Server error' } };
  }
}
