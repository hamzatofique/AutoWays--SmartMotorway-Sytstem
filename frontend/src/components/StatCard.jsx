export default function StatCard({ value, label }) {
  return (
    <div className="card">
      <div className="num">{value}</div>
      <div className="label">{label}</div>
    </div>
  );
}