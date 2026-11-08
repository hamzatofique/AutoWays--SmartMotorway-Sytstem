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
app.listen(process.env.PORT,()=>
    console.log('API running on port'+process.env.PORT));