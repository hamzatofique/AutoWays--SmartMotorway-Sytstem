const express = require('express');
const pool = require('../config/db');
const router = express.Router();

// all plazas, with lane count and number of faulty lanes
router.get('/toll/plazas', async (req, res) => {
  try {
    const r = await pool.query(
      `SELECT p.plaza_id, p.plaza_code, i.name AS interchange, p.total_booths,
              p.supervisor_phone,
              COUNT(l.lane_id)::int AS lanes,
              COUNT(*) FILTER (WHERE l.barrier_status = 'Fault')::int AS faulty
       FROM Toll_Plaza p
       JOIN Interchange i ON i.interchange_id = p.interchange_id
       LEFT JOIN Toll_Lane l ON l.plaza_id = p.plaza_id
       GROUP BY p.plaza_id, i.name
       ORDER BY p.plaza_id`);
    res.json(r.rows);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// lanes of one plaza
router.get('/toll/plazas/:id/lanes', async (req, res) => {
  try {
    const r = await pool.query(
      `SELECT lane_id, lane_number, lane_type, rfid_reader_serial,
              anpr_unit_serial, barrier_status
       FROM Toll_Lane WHERE plaza_id = $1 ORDER BY lane_number`, [req.params.id]);
    res.json(r.rows);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// latest trips that entered or left through this plaza
router.get('/toll/plazas/:id/trips', async (req, res) => {
  try {
    const r = await pool.query(
      `SELECT tr.trip_id, v.plate_no, el.lane_number AS entry_lane,
              tr.entry_time, tr.exit_time, tr.trip_status,
              tr.toll_deducted, tr.computed_avg_speed_kmh
       FROM Toll_Transit_Trip tr
       JOIN Toll_Lane el ON el.lane_id = tr.entry_lane_id
       JOIN MTag_Account t ON t.mtag_id = tr.mtag_id
       JOIN Registered_Vehicle v ON v.vehicle_id = t.vehicle_id
       WHERE el.plaza_id = $1
          OR tr.exit_lane_id IN (SELECT lane_id FROM Toll_Lane WHERE plaza_id = $1)
       ORDER BY tr.entry_time DESC LIMIT 20`, [req.params.id]);
    res.json(r.rows);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// change a lane's barrier status
router.patch('/toll/lanes/:id/barrier', async (req, res) => {
  const status = req.body.barrier_status;
  if (!['Open', 'Closed', 'Fault'].includes(status))
    return res.status(400).json({ error: 'barrier_status must be Open, Closed or Fault' });
  try {
    const r = await pool.query(
      `UPDATE Toll_Lane SET barrier_status = $1 WHERE lane_id = $2
       RETURNING lane_id, barrier_status`, [status, req.params.id]);
    if (!r.rows.length) return res.status(404).json({ error: 'Lane not found' });
    res.json(r.rows[0]);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

module.exports = router;