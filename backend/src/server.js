require('dotenv').config();
const express =require('express');
const cors =require('cors');
const pool =require('./config/db');

const app=express();
app.use(cors());
app.use(express.json());
app.get('/api/health',async(req,res)=>{
    try{
        const r=await pool.query('SELECT NOW() AS time');
        res.json({status:'ok',db_time:r.rows[0].time});
    }catch(e){
        res.status(500).json({error:e.message});
    }

});
app.get('/api/stats', async (req, res) => {
  try {
    const r = await pool.query(`
      SELECT
        (SELECT COUNT(*) FROM Motorist) AS motorists,
        (SELECT COUNT(*) FROM Registered_Vehicle) AS vehicles,
        (SELECT COUNT(*) FROM Toll_Transit_Trip) AS trips,
        (SELECT COUNT(*) FROM E_Challan_Ticket WHERE payment_status = 'Unpaid') AS unpaid_challans,
        (SELECT COUNT(*) FROM Highway_Incident WHERE status <> 'Cleared') AS open_incidents`);
    res.json(r.rows[0]);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});
app.listen(process.env.PORT,()=>
    console.log('API running on port'+process.env.PORT));