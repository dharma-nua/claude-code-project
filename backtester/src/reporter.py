import os
import csv
import json
from datetime import datetime, timezone
from .models import BacktestResult


def generate_outputs(result: BacktestResult, output_dir: str) -> dict[str, str]:
    """Write all 5 output files. Returns dict of {name: filepath}."""
    os.makedirs(output_dir, exist_ok=True)
    paths = {}

    paths["trades"] = _write_trades_csv(result, output_dir)
    paths["journal"] = _write_journal_csv(result, output_dir)
    paths["summary"] = _write_summary_json(result, output_dir)
    paths["report"] = _write_report_html(result, output_dir)
    paths["simulation"] = _write_simulation_json(result, output_dir)

    return paths


def _write_trades_csv(result: BacktestResult, output_dir: str) -> str:
    filepath = os.path.join(output_dir, "trades.csv")
    fieldnames = [
        "trade_id", "symbol", "direction",
        "entry_timestamp", "entry_price",
        "exit_timestamp", "exit_price",
        "pips", "close_reason",
    ]
    with open(filepath, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        for t in result.trades:
            writer.writerow({
                "trade_id": t.trade_id,
                "symbol": t.symbol,
                "direction": t.direction,
                "entry_timestamp": t.entry_timestamp,
                "entry_price": t.entry_price,
                "exit_timestamp": t.exit_timestamp,
                "exit_price": t.exit_price,
                "pips": t.pips,
                "close_reason": t.close_reason,
            })
    return filepath


def _write_journal_csv(result: BacktestResult, output_dir: str) -> str:
    filepath = os.path.join(output_dir, "journal.csv")
    fieldnames = [
        "bar", "timestamp", "symbol",
        "open", "high", "low", "close",
        "signal", "action", "position", "running_pips",
    ]
    with open(filepath, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        for j in result.journal:
            writer.writerow({
                "bar": j.bar,
                "timestamp": j.timestamp,
                "symbol": j.symbol,
                "open": j.open,
                "high": j.high,
                "low": j.low,
                "close": j.close,
                "signal": j.signal,
                "action": j.action,
                "position": j.position_direction or "",
                "running_pips": j.running_pips,
            })
    return filepath


def _write_summary_json(result: BacktestResult, output_dir: str) -> str:
    filepath = os.path.join(output_dir, "summary.json")
    with open(filepath, "w", encoding="utf-8") as f:
        json.dump(result.summary, f, indent=2)
    return filepath


def _write_simulation_json(result: BacktestResult, output_dir: str) -> str:
    filepath = os.path.join(output_dir, "simulation.json")
    cfg = result.config
    payload = {
        "run_id": cfg.run_id,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "phase": cfg.phase,
        "symbols": cfg.symbols,
        "date_range": cfg.date_range,
        "reverse_on_flip": cfg.reverse_on_flip,
        "lot_size": cfg.lot_size,
        "pip_value": cfg.pip_value,
        "spread": cfg.spread,
        "commission": cfg.commission,
        "total_bars_processed": len(result.journal),
        "total_trades": len(result.trades),
        "selected_indicator_id": cfg.selected_indicator_id,
        "selected_indicator_hash": cfg.selected_indicator_hash,
        "mapped_signal_csv_path": cfg.mapped_signal_csv_path,
        "mapped_signal_csv_hash": cfg.mapped_signal_csv_hash,
        "candle_source_type": cfg.candle_source_type,
        "candle_normalized_output_path": cfg.candle_normalized_output_path,
        "statement_import_run_id": cfg.statement_import_run_id,
    }
    with open(filepath, "w", encoding="utf-8") as f:
        json.dump(payload, f, indent=2)
    return filepath


def _write_report_html(result: BacktestResult, output_dir: str) -> str:
    filepath = os.path.join(output_dir, "report.html")
    cfg = result.config
    s = result.summary

    date_from = cfg.date_range.get("from") or "—"
    date_to = cfg.date_range.get("to") or "—"
    symbols_str = ", ".join(cfg.symbols)
    generated_at = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")

    # Build trades rows
    trade_rows = ""
    for t in result.trades:
        pip_class = "positive" if t.pips > 0 else "negative"
        trade_rows += f"""
        <tr>
          <td>{t.symbol}</td>
          <td>{t.direction}</td>
          <td>{t.entry_timestamp}</td>
          <td>{t.entry_price}</td>
          <td>{t.exit_timestamp}</td>
          <td>{t.exit_price}</td>
          <td class="{pip_class}">{t.pips:+.2f}</td>
          <td>{t.close_reason}</td>
        </tr>"""

    pf = f"{s['profit_factor']:.4f}" if s["profit_factor"] is not None else "N/A"

    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Backtest Report — {cfg.run_id[:8]}</title>
<style>
  *, *::before, *::after {{ box-sizing: border-box; margin: 0; padding: 0; }}
  body {{
    background: #0f1117;
    color: #e0e0e0;
    font-family: 'Segoe UI', system-ui, sans-serif;
    font-size: 14px;
    padding: 32px;
  }}
  h1 {{ font-size: 24px; color: #ffffff; margin-bottom: 4px; }}
  h2 {{ font-size: 16px; color: #aaa; margin: 24px 0 12px; }}
  .meta {{ color: #888; font-size: 12px; margin-bottom: 24px; }}
  .meta span {{ margin-right: 24px; }}
  .cards {{
    display: flex; flex-wrap: wrap; gap: 16px; margin-bottom: 32px;
  }}
  .card {{
    background: #1e2130;
    border: 1px solid #2d3147;
    border-radius: 8px;
    padding: 16px 24px;
    min-width: 140px;
  }}
  .card .label {{ font-size: 11px; color: #888; text-transform: uppercase; letter-spacing: 0.05em; }}
  .card .value {{ font-size: 22px; font-weight: 700; margin-top: 4px; color: #fff; }}
  .positive {{ color: #4caf50; }}
  .negative {{ color: #f44336; }}
  table {{
    width: 100%;
    border-collapse: collapse;
    margin-bottom: 32px;
  }}
  th, td {{
    text-align: left;
    padding: 8px 12px;
    border-bottom: 1px solid #2d3147;
  }}
  th {{
    background: #1e2130;
    color: #aaa;
    font-size: 11px;
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }}
  tr:hover {{ background: #1a1e2d; }}
  .run-id {{ font-family: monospace; font-size: 12px; color: #888; }}
</style>
</head>
<body>
<h1>Backtest Report</h1>
<div class="meta">
  <span><strong>Run ID:</strong> <span class="run-id">{cfg.run_id}</span></span>
  <span><strong>Phase:</strong> {cfg.phase}</span>
  <span><strong>Generated:</strong> {generated_at}</span>
  <span><strong>Symbols:</strong> {symbols_str}</span>
  <span><strong>Date Range:</strong> {date_from} → {date_to}</span>
  <span><strong>Reverse on Flip:</strong> {"Yes" if cfg.reverse_on_flip else "No"}</span>
</div>

<h2>Summary</h2>
<div class="cards">
  <div class="card">
    <div class="label">Total Trades</div>
    <div class="value">{s['total_trades']}</div>
  </div>
  <div class="card">
    <div class="label">Win Rate</div>
    <div class="value">{s['win_rate']*100:.1f}%</div>
  </div>
  <div class="card">
    <div class="label">Total Pips</div>
    <div class="value {'positive' if s['total_pips'] >= 0 else 'negative'}">{s['total_pips']:+.2f}</div>
  </div>
  <div class="card">
    <div class="label">Profit Factor</div>
    <div class="value">{pf}</div>
  </div>
  <div class="card">
    <div class="label">Avg Pips / Trade</div>
    <div class="value {'positive' if s['avg_pips_per_trade'] >= 0 else 'negative'}">{s['avg_pips_per_trade']:+.2f}</div>
  </div>
  <div class="card">
    <div class="label">Max Drawdown</div>
    <div class="value negative">-{s['max_drawdown_pips']:.2f}</div>
  </div>
  <div class="card">
    <div class="label">Missing Signal Rate</div>
    <div class="value">{s['missing_signal_rate']*100:.1f}%</div>
  </div>
</div>

<h2>Trades ({s['total_trades']})</h2>
<table>
  <thead>
    <tr>
      <th>Symbol</th><th>Direction</th>
      <th>Entry Date</th><th>Entry Price</th>
      <th>Exit Date</th><th>Exit Price</th>
      <th>Pips</th><th>Reason</th>
    </tr>
  </thead>
  <tbody>
    {trade_rows}
  </tbody>
</table>

</body>
</html>"""

    with open(filepath, "w", encoding="utf-8") as f:
        f.write(html)
    return filepath
