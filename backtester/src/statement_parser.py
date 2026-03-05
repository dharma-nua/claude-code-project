import csv
import json
from pathlib import Path

import pandas as pd
from bs4 import BeautifulSoup


def parse_statement(uploaded_file) -> tuple[bool, list[dict], dict, str]:
    """Parse MT4/Soft4FX HTML statement.
    Returns (success, trades_list, summary_dict, error_msg).
    On failure returns (False, [], {}, error_msg)."""
    if hasattr(uploaded_file, "read"):
        content = uploaded_file.read()
        if isinstance(content, str):
            content = content.encode("utf-8", errors="replace")
    else:
        content = bytes(uploaded_file)

    try:
        soup = BeautifulSoup(content, "html.parser")
    except Exception as exc:
        return False, [], {}, f"Failed to parse HTML: {exc}"

    try:
        trades = _extract_closed_trades(soup)
        summary = _extract_summary(soup)
    except Exception as exc:
        return False, [], {}, f"Extraction error: {exc}"

    if not trades and not summary:
        return False, [], {}, "No recognizable MT4/Soft4FX sections found in HTML."

    return True, trades, summary, ""


def save_statement_outputs(
    trades: list[dict],
    summary: dict,
    output_dir: Path,
) -> tuple[Path, Path]:
    """Write statement_trades.csv and statement_summary.json. Returns (csv_path, json_path)."""
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    csv_path = output_dir / "statement_trades.csv"
    if trades:
        fieldnames = list(trades[0].keys())
        with open(csv_path, "w", newline="", encoding="utf-8") as f:
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()
            writer.writerows(trades)
    else:
        csv_path.write_text("ticket,symbol,type,lots,open_time,open_price,close_time,close_price,profit\n",
                             encoding="utf-8")

    json_path = output_dir / "statement_summary.json"
    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(summary, f, indent=2)

    return csv_path, json_path


def _extract_closed_trades(soup) -> list[dict]:
    """Find 'Closed Transactions' table rows."""
    target_table = None

    for table in soup.find_all("table"):
        text = table.get_text(" ", strip=True).lower()
        if "ticket" in text or "order" in text:
            headers_row = table.find("tr")
            if headers_row:
                headers = [th.get_text(strip=True).lower() for th in headers_row.find_all(["th", "td"])]
                if "ticket" in headers or "order" in headers:
                    target_table = table
                    break

    if target_table is None:
        return []

    rows = target_table.find_all("tr")
    if not rows:
        return []

    header_cells = [h.get_text(strip=True).lower() for h in rows[0].find_all(["th", "td"])]

    key_map = {
        "ticket": "ticket",
        "order": "ticket",
        "symbol": "symbol",
        "type": "type",
        "lots": "lots",
        "size": "lots",
        "open time": "open_time",
        "open price": "open_price",
        "close time": "close_time",
        "close price": "close_price",
        "profit": "profit",
        "s/l": None,
        "t/p": None,
        "commission": None,
        "swap": None,
    }

    col_indices = {}
    for idx, h in enumerate(header_cells):
        if h in key_map and key_map[h] is not None:
            col_indices[key_map[h]] = idx

    trades = []
    for row in rows[1:]:
        cells = [td.get_text(strip=True) for td in row.find_all(["td", "th"])]
        if len(cells) < 2:
            continue
        trade = {}
        for field, idx in col_indices.items():
            trade[field] = cells[idx] if idx < len(cells) else ""

        if not any(trade.values()):
            continue
        trades.append(trade)

    return trades


def _extract_summary(soup) -> dict:
    """Extract summary metrics table."""
    summary = {}

    text_lower = soup.get_text(" ", strip=True).lower()
    has_summary = "profit factor" in text_lower or "net profit" in text_lower
    if not has_summary:
        return summary

    search_terms = {
        "net profit": "net_profit",
        "profit factor": "profit_factor",
        "absolute drawdown": "drawdown_pct",
        "maximal drawdown": "drawdown_pct",
        "total trades": "total_trades",
        "total closed trades": "total_trades",
    }

    for table in soup.find_all("table"):
        for row in table.find_all("tr"):
            cells = [td.get_text(strip=True) for td in row.find_all(["td", "th"])]
            for i, cell in enumerate(cells):
                cell_lower = cell.lower()
                for term, key in search_terms.items():
                    if term in cell_lower and i + 1 < len(cells):
                        raw_val = cells[i + 1].replace(",", "").replace("%", "").strip()
                        if raw_val:
                            try:
                                summary[key] = float(raw_val)
                            except ValueError:
                                summary[key] = raw_val
                        break

    winning_pattern = ["short trades", "long trades"]
    trades_total = summary.get("total_trades", 0)
    if trades_total:
        summary.setdefault("winning_trades", None)
        summary.setdefault("losing_trades", None)

    return summary
