def compare_results(sim_summary: dict, stmt_summary: dict) -> dict:
    """Return side-by-side comparison.
    Output schema:
    {
      "metrics": [
        {"metric": str, "simulation": val, "statement": val, "delta": val},
        ...
      ]
    }"""
    metric_pairs = [
        ("total_trades", "total_trades", "Total Trades"),
        ("win_rate", "win_rate", "Win Rate"),
        ("total_pips", "net_profit", "Total Pips / Net Profit"),
        ("profit_factor", "profit_factor", "Profit Factor"),
        ("max_drawdown_pips", "drawdown_pct", "Max Drawdown"),
    ]

    rows = []
    for sim_key, stmt_key, label in metric_pairs:
        sim_val = sim_summary.get(sim_key)
        stmt_val = stmt_summary.get(stmt_key)

        if sim_val is not None and stmt_val is not None:
            try:
                delta = float(sim_val) - float(stmt_val)
            except (TypeError, ValueError):
                delta = None
        else:
            delta = None

        rows.append({
            "metric": label,
            "simulation": sim_val,
            "statement": stmt_val,
            "delta": delta,
        })

    return {"metrics": rows}
