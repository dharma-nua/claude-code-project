import os
import json
import tempfile
from datetime import date
from pathlib import Path

import streamlit as st
import pandas as pd

from src.parser import parse_candles, parse_signals
from src.validator import validate_candles, validate_signals, validate_alignment
from src.engine import BacktestEngine
from src.models import BacktestConfig
from src.reporter import generate_outputs
from src import ctf_adapter, indicator_library, mapping_manager, comparator
from src.statement_parser import parse_statement, save_statement_outputs
from bridge import job_manager

st.set_page_config(
    page_title="Backtester — Phase 1.5",
    page_icon="📈",
    layout="wide",
)

st.title("📈 Phase 1.5 Backtester — C1-Only Engine")

# ─── Session state initialization ───────────────────────────────────────────
for key, default in [
    ("candles_df", None),
    ("signals_df", None),
    ("candles_valid", False),
    ("signals_valid", False),
    ("backtest_result", None),
    ("output_paths", None),
    ("run_log", []),
    ("candle_source_type", "csv"),
    ("selected_indicator_id", None),
    ("stmt_summary", None),
    ("last_run_id", None),
]:
    if key not in st.session_state:
        st.session_state[key] = default

ALLOWED_SYMBOLS = ["EURUSD", "EURGBP", "AUDNZD", "AUDCAD", "CHFJPY"]

tab_upload, tab_indicators, tab_setup, tab_run, tab_results, tab_bridge, tab_statement = st.tabs([
    "📂 Upload Data",
    "📚 Indicator Library",
    "⚙️ Setup",
    "▶️ Run",
    "📊 Results",
    "🌉 Bridge",
    "📋 Statement Import",
])

# ═══════════════════════════════════════════════════════════════════════
# TAB 1 — Upload Data
# ═══════════════════════════════════════════════════════════════════════
with tab_upload:
    st.subheader("Upload Data Files")
    st.caption("Upload candles (CSV or CTF) and signals CSVs. Files are validated immediately on upload.")

    col_c, col_s = st.columns(2)

    with col_c:
        st.markdown("**Candles — CSV**")
        st.caption("Required columns: timestamp, symbol, timeframe, open, high, low, close, volume")
        candles_file = st.file_uploader("Upload candles CSV", type="csv", key="candles_uploader")

        if candles_file:
            try:
                df = parse_candles(candles_file)
                ok, errors = validate_candles(df)
                if ok:
                    st.session_state.candles_df = df
                    st.session_state.candles_valid = True
                    st.session_state.candle_source_type = "csv"
                    st.success(f"✅ Candles valid — {len(df)} rows, {df['symbol'].nunique()} symbol(s)")
                else:
                    st.session_state.candles_valid = False
                    st.error("❌ Candles validation failed:")
                    for e in errors:
                        st.markdown(f"- {e}")
                st.markdown("**Preview (first 10 rows):**")
                st.dataframe(df.head(10), use_container_width=True)
            except Exception as exc:
                st.session_state.candles_valid = False
                st.error(f"Failed to parse candles: {exc}")

        st.markdown("**Candles — CTF** *(optional alternative)*")
        ctf_file = st.file_uploader("Upload candles CTF", type=["ctf"], key="ctf_uploader")

        if ctf_file:
            success, df_ctf, msg = ctf_adapter.parse_ctf(ctf_file)
            if success:
                st.session_state.candles_df = df_ctf
                st.session_state.candles_valid = True
                st.session_state.candle_source_type = "ctf"
                st.success(f"✅ {msg}")
                st.dataframe(df_ctf.head(10), use_container_width=True)
            else:
                st.warning(f"⚠️ {msg}")

    with col_s:
        st.markdown("**Signals CSV**")
        st.caption("Required columns: timestamp, symbol, signal (values: -1, 0, 1)")
        signals_file = st.file_uploader("Upload signals CSV", type="csv", key="signals_uploader")

        if signals_file:
            try:
                df = parse_signals(signals_file)
                ok, errors = validate_signals(df)
                if ok:
                    st.session_state.signals_df = df
                    st.session_state.signals_valid = True
                    st.success(f"✅ Signals valid — {len(df)} rows, {df['symbol'].nunique()} symbol(s)")
                else:
                    st.session_state.signals_valid = False
                    st.error("❌ Signals validation failed:")
                    for e in errors:
                        st.markdown(f"- {e}")
                st.markdown("**Preview (first 10 rows):**")
                st.dataframe(df.head(10), use_container_width=True)
            except Exception as exc:
                st.session_state.signals_valid = False
                st.error(f"Failed to parse signals: {exc}")

    if st.session_state.candles_valid and st.session_state.signals_valid:
        warnings = validate_alignment(st.session_state.candles_df, st.session_state.signals_df)
        if warnings:
            st.warning("⚠️ Alignment warnings:")
            for w in warnings:
                st.markdown(f"- {w}")
        else:
            st.info("✅ Candles and signals are fully aligned.")


# ═══════════════════════════════════════════════════════════════════════
# TAB 2 — Indicator Library
# ═══════════════════════════════════════════════════════════════════════
with tab_indicators:
    st.subheader("Indicator Library")

    # ── Upload new indicator ───────────────────────────────────────────
    with st.expander("Add Indicator", expanded=True):
        up_col, type_col, notes_col = st.columns([3, 2, 3])
        with up_col:
            ind_file = st.file_uploader("Upload .mq4 or .ex4", type=["mq4", "ex4"], key="ind_uploader")
        with type_col:
            mod_type = st.selectbox("Module Type", sorted(indicator_library.ALLOWED_MODULE_TYPES))
        with notes_col:
            ind_notes = st.text_input("Notes (optional)")

        if st.button("Add to Library", disabled=(ind_file is None)):
            try:
                entry = indicator_library.add_indicator(ind_file, mod_type, ind_notes)
                st.success(f"✅ Added '{entry['name']}' (ID: {entry['id'][:8]}…)")
                st.rerun()
            except ValueError as exc:
                st.error(f"❌ {exc}")

    # ── Library table ─────────────────────────────────────────────────
    st.markdown("### Library")
    search_name = st.text_input("Search by name or module type", key="lib_search")
    indicators = indicator_library.list_indicators()

    if search_name:
        q = search_name.lower()
        indicators = [i for i in indicators if q in i["name"].lower() or q in i["module_type"].lower()]

    if not indicators:
        st.info("No indicators in library yet.")
    else:
        display_df = pd.DataFrame([{
            "ID": i["id"][:8] + "…",
            "Name": i["name"],
            "Type": i["module_type"],
            "Status": i["status"],
            "Uploaded": i["uploaded_at"][:10],
            "Notes": i["notes"],
        } for i in indicators])
        st.dataframe(display_df, use_container_width=True)

        st.markdown("**Toggle Status**")
        toggle_options = {f"{i['name']} ({i['id'][:8]}…)": i["id"] for i in indicators}
        selected_toggle = st.selectbox("Select indicator to toggle", list(toggle_options.keys()),
                                       key="toggle_select")
        toggle_id = toggle_options[selected_toggle]
        toggle_entry = next(i for i in indicators if i["id"] == toggle_id)
        new_status = "inactive" if toggle_entry["status"] == "active" else "active"
        if st.button(f"Set to {new_status.capitalize()}"):
            indicator_library.toggle_status(toggle_id, new_status)
            st.success(f"✅ Set to {new_status}")
            st.rerun()


# ═══════════════════════════════════════════════════════════════════════
# TAB 3 — Setup
# ═══════════════════════════════════════════════════════════════════════
with tab_setup:
    st.subheader("Backtest Configuration")

    col_left, col_right = st.columns(2)

    with col_left:
        selected_symbols = st.multiselect(
            "Symbols",
            options=ALLOWED_SYMBOLS,
            default=ALLOWED_SYMBOLS,
            help="Select which symbols to include in the backtest.",
        )

        col_d1, col_d2 = st.columns(2)
        with col_d1:
            date_from = st.date_input("Date From (optional)", value=None)
        with col_d2:
            date_to = st.date_input("Date To (optional)", value=None)

        reverse_on_flip = st.toggle(
            "Reverse on Flip",
            value=False,
            help="When enabled: closing a long automatically opens a short (and vice versa).",
        )

    with col_right:
        with st.expander("Reserved Fields (not used in P&L yet)", expanded=False):
            lot_size = st.number_input("Lot Size", min_value=0.0, value=0.0, step=0.01)
            pip_value = st.number_input("Pip Value ($)", min_value=0.0, value=0.0, step=0.01)
            spread = st.number_input("Spread (pips)", min_value=0.0, value=0.0, step=0.1)
            commission = st.number_input("Commission per trade ($)", min_value=0.0, value=0.0, step=0.01)

    # ── Indicator selector ─────────────────────────────────────────────
    st.divider()
    st.markdown("### Indicator & Signal Mapping")

    active_indicators = [i for i in indicator_library.list_indicators() if i["status"] == "active"]
    ind_options = {"(none — use manual signal upload)": None}
    ind_options.update({f"{i['name']} [{i['module_type']}] ({i['id'][:8]}…)": i["id"] for i in active_indicators})

    prev_ind = st.session_state.selected_indicator_id
    selected_ind_label = st.selectbox("Select Indicator (optional)", list(ind_options.keys()))
    selected_ind_id = ind_options[selected_ind_label]
    st.session_state.selected_indicator_id = selected_ind_id

    if selected_ind_id and selected_ind_id != prev_ind:
        mapping = mapping_manager.get_mapping(selected_ind_id)
        if mapping:
            csv_path = Path(mapping["signal_csv_path"])
            if csv_path.exists():
                try:
                    df = pd.read_csv(csv_path)
                    ok, errors = validate_signals(df)
                    if ok:
                        st.session_state.signals_df = df
                        st.session_state.signals_valid = True
                        st.success(f"✅ Mapping loaded: {csv_path.name} ({len(df)} rows)")
                    else:
                        st.error("Mapped signal CSV failed validation.")
                except Exception as exc:
                    st.error(f"Failed to load mapped signal CSV: {exc}")
            else:
                st.warning("Mapped signal CSV path no longer exists.")

    if selected_ind_id:
        mapping = mapping_manager.get_mapping(selected_ind_id)
        if mapping:
            st.info(f"Mapping attached: `{Path(mapping['signal_csv_path']).name}`")
        else:
            st.warning("No signal mapping attached to this indicator. "
                       "Attach one below or upload signals manually in Upload Data tab.")

            with st.expander("Attach Signal Mapping"):
                attach_file = st.file_uploader("Upload signal CSV to attach", type="csv", key="attach_sig")
                if attach_file and st.button("Attach Mapping"):
                    try:
                        df_att = pd.read_csv(attach_file)
                        ok, errors = mapping_manager.validate_mapping_csv(df_att)
                        if not ok:
                            st.error("Validation failed:")
                            for e in errors:
                                st.markdown(f"- {e}")
                        else:
                            with tempfile.NamedTemporaryFile(
                                suffix=".csv", delete=False, dir=Path(__file__).parent / "imports"
                            ) as tmp:
                                df_att.to_csv(tmp.name, index=False)
                                mapping_manager.attach_mapping(selected_ind_id, tmp.name)
                            st.success("✅ Mapping attached.")
                            st.rerun()
                    except Exception as exc:
                        st.error(f"Error: {exc}")

    st.session_state.setup_config = {
        "symbols": selected_symbols,
        "date_from": str(date_from) if date_from else None,
        "date_to": str(date_to) if date_to else None,
        "reverse_on_flip": reverse_on_flip,
        "lot_size": lot_size if lot_size > 0 else None,
        "pip_value": pip_value if pip_value > 0 else None,
        "spread": spread if spread > 0 else None,
        "commission": commission if commission > 0 else None,
    }

    st.info(f"Ready to run: **{len(selected_symbols)}** symbol(s) selected. "
            f"Reverse on flip: **{'ON' if reverse_on_flip else 'OFF'}**.")


# ═══════════════════════════════════════════════════════════════════════
# TAB 4 — Run
# ═══════════════════════════════════════════════════════════════════════
with tab_run:
    st.subheader("Run Backtest")

    both_valid = st.session_state.candles_valid and st.session_state.signals_valid
    if not both_valid:
        st.warning("⚠️ Please upload and validate both candles and signals files before running.")

    setup = st.session_state.get("setup_config", {})
    if not setup.get("symbols"):
        st.error("No symbols selected. Go to Setup tab and select at least one symbol.")

    run_disabled = not both_valid or not setup.get("symbols")

    run_btn = st.button("▶️ Run Backtest", disabled=run_disabled, type="primary")

    if run_btn:
        st.session_state.run_log = []
        progress = st.progress(0, text="Initializing…")
        log_box = st.empty()

        log_lines = []

        def log_callback(msg: str):
            log_lines.append(msg)
            log_box.code("\n".join(log_lines[-40:]), language=None)

        config = BacktestConfig(
            symbols=setup["symbols"],
            date_range={"from": setup.get("date_from"), "to": setup.get("date_to")},
            reverse_on_flip=setup.get("reverse_on_flip", False),
            lot_size=setup.get("lot_size"),
            pip_value=setup.get("pip_value"),
            spread=setup.get("spread"),
            commission=setup.get("commission"),
            candle_source_type=st.session_state.candle_source_type,
            selected_indicator_id=st.session_state.selected_indicator_id,
        )

        progress.progress(10, text="Running simulation…")
        engine = BacktestEngine()
        result = engine.run(
            st.session_state.candles_df,
            st.session_state.signals_df,
            config,
            log_callback=log_callback,
        )
        progress.progress(70, text="Generating output files…")

        output_dir = os.path.join(os.path.dirname(__file__), "outputs", config.run_id[:8])
        paths = generate_outputs(result, output_dir)

        st.session_state.backtest_result = result
        st.session_state.output_paths = paths
        st.session_state.run_log = log_lines
        st.session_state.last_run_id = config.run_id

        progress.progress(100, text="Done!")
        st.success(
            f"✅ Backtest complete — {len(result.trades)} trades, "
            f"{result.summary['total_pips']:+.2f} total pips. "
            f"View results in the **Results** tab."
        )

    elif st.session_state.run_log:
        st.code("\n".join(st.session_state.run_log[-40:]), language=None)

    st.button("⏹ Stop", disabled=True, help="Stop functionality available in a future phase.")


# ═══════════════════════════════════════════════════════════════════════
# TAB 5 — Results
# ═══════════════════════════════════════════════════════════════════════
with tab_results:
    st.subheader("Results")

    result = st.session_state.backtest_result
    paths = st.session_state.output_paths

    if result is None:
        st.info("No results yet. Run a backtest first.")
    else:
        s = result.summary

        st.markdown("### Summary")
        c1, c2, c3, c4, c5, c6 = st.columns(6)
        c1.metric("Total Trades", s["total_trades"])
        c2.metric("Win Rate", f"{s['win_rate']*100:.1f}%")
        c3.metric("Total Pips", f"{s['total_pips']:+.2f}")
        pf_str = f"{s['profit_factor']:.2f}" if s["profit_factor"] is not None else "N/A"
        c4.metric("Profit Factor", pf_str)
        c5.metric("Avg Pips/Trade", f"{s['avg_pips_per_trade']:+.2f}")
        c6.metric("Max Drawdown", f"-{s['max_drawdown_pips']:.2f}")

        st.markdown(
            f"**Run ID:** `{result.config.run_id}` &nbsp;|&nbsp; "
            f"**Phase:** {result.config.phase} &nbsp;|&nbsp; "
            f"**Missing Signal Rate:** {s['missing_signal_rate']*100:.1f}%"
        )

        st.divider()

        st.markdown("### Trades")
        if result.trades:
            trades_data = [
                {
                    "symbol": t.symbol,
                    "direction": t.direction,
                    "entry": t.entry_timestamp,
                    "entry_price": t.entry_price,
                    "exit": t.exit_timestamp,
                    "exit_price": t.exit_price,
                    "pips": t.pips,
                    "reason": t.close_reason,
                }
                for t in result.trades
            ]
            trades_df = pd.DataFrame(trades_data)
            st.dataframe(trades_df, use_container_width=True)
        else:
            st.info("No trades generated.")

        st.divider()

        st.markdown("### Journal")
        if result.journal:
            symbol_filter = st.selectbox(
                "Filter by symbol",
                options=["All"] + sorted(set(j.symbol for j in result.journal)),
            )
            journal_data = [
                {
                    "bar": j.bar,
                    "timestamp": j.timestamp,
                    "symbol": j.symbol,
                    "close": j.close,
                    "signal": j.signal,
                    "action": j.action,
                    "position": j.position_direction or "—",
                    "running_pips": j.running_pips,
                }
                for j in result.journal
            ]
            journal_df = pd.DataFrame(journal_data)
            if symbol_filter != "All":
                journal_df = journal_df[journal_df["symbol"] == symbol_filter]
            st.dataframe(journal_df, use_container_width=True)

        st.divider()

        st.markdown("### Download Output Files")
        if paths:
            dl_cols = st.columns(5)
            file_labels = [
                ("trades", "trades.csv", "text/csv"),
                ("journal", "journal.csv", "text/csv"),
                ("summary", "summary.json", "application/json"),
                ("report", "report.html", "text/html"),
                ("simulation", "simulation.json", "application/json"),
            ]
            for col, (key, filename, mime) in zip(dl_cols, file_labels):
                if key in paths and os.path.exists(paths[key]):
                    with open(paths[key], "rb") as f:
                        col.download_button(
                            label=f"⬇️ {filename}",
                            data=f.read(),
                            file_name=filename,
                            mime=mime,
                            use_container_width=True,
                        )

        # ── Compare with imported statement ───────────────────────────
        if st.session_state.stmt_summary:
            with st.expander("Compare with Imported Statement", expanded=False):
                comparison = comparator.compare_results(s, st.session_state.stmt_summary)
                cmp_df = pd.DataFrame(comparison["metrics"])
                st.dataframe(cmp_df, use_container_width=True)


# ═══════════════════════════════════════════════════════════════════════
# TAB 6 — Bridge
# ═══════════════════════════════════════════════════════════════════════
with tab_bridge:
    st.subheader("Bridge — MT4 Execution")

    available = job_manager.is_bridge_available()
    if available:
        st.success("✅ Bridge directories available and writable.")
    else:
        st.error("❌ Cannot execute mq4/ctf directly. Start bridge or attach normalized CSV files.")

    ind_id = st.session_state.selected_indicator_id
    run_id = st.session_state.last_run_id

    if not st.session_state.signals_valid and ind_id and available:
        st.markdown("### Bridge Required")
        st.info("No signal mapping found for the selected indicator. Submit a job to the bridge to generate signals.")

        ind_entry = indicator_library.get_indicator(ind_id) if ind_id else None
        if ind_entry:
            if st.button("Submit to Bridge"):
                setup_cfg = st.session_state.get("setup_config", {})
                new_run_id = str(__import__("uuid").uuid4())
                job_manager.write_job(
                    run_id=new_run_id,
                    indicator_id=ind_id,
                    indicator_file=ind_entry["file_name"],
                    candle_source_type=st.session_state.candle_source_type,
                    candle_file=None,
                    config_dict={
                        "symbols": setup_cfg.get("symbols", ALLOWED_SYMBOLS),
                        "date_range": {
                            "from": setup_cfg.get("date_from"),
                            "to": setup_cfg.get("date_to"),
                        },
                    },
                )
                st.session_state.last_run_id = new_run_id
                st.success(f"✅ Job submitted. Run ID: `{new_run_id[:8]}…`")
                st.rerun()

    if run_id:
        st.markdown("### Job Status")
        if st.button("Refresh Status"):
            status_info = job_manager.read_job_status(run_id)
            status = status_info["status"]
            st.write(f"**Status:** {status}")

            if status == "done":
                outputs = job_manager.get_done_outputs(run_id)
                if "normalized_signals" in outputs:
                    try:
                        df_sig = pd.read_csv(outputs["normalized_signals"])
                        ok, errors = validate_signals(df_sig)
                        if ok:
                            st.session_state.signals_df = df_sig
                            st.session_state.signals_valid = True
                            st.success("✅ Signals loaded from bridge output.")
                        else:
                            st.error("Bridge signals failed validation.")
                    except Exception as exc:
                        st.error(f"Failed to load bridge signals: {exc}")

            elif status == "failed":
                job_data = status_info.get("job", {})
                st.error(f"Bridge job failed: {job_data.get('error', 'unknown error')}")

    st.divider()
    st.markdown("### Pending Jobs")
    pending = job_manager.list_pending_jobs()
    if pending:
        st.dataframe(pd.DataFrame(pending)[["job_id", "created_at", "indicator_id", "status"]],
                     use_container_width=True)
    else:
        st.caption("No pending jobs.")

    st.markdown("### Done Jobs")
    done = job_manager.list_done_jobs()
    if done:
        st.dataframe(pd.DataFrame(done), use_container_width=True)
    else:
        st.caption("No done jobs.")


# ═══════════════════════════════════════════════════════════════════════
# TAB 7 — Statement Import
# ═══════════════════════════════════════════════════════════════════════
with tab_statement:
    st.subheader("Statement Import — MT4 / Soft4FX HTML Report")

    stmt_file = st.file_uploader("Upload MT4/Soft4FX HTML statement", type=["html", "htm"])

    if stmt_file:
        success, trades, summary, err_msg = parse_statement(stmt_file)

        if success:
            st.success(f"✅ Parsed successfully — {len(trades)} closed trade(s).")
            st.session_state.stmt_summary = summary

            if summary:
                st.markdown("**Summary Metrics**")
                st.json(summary)

            if trades:
                st.markdown("**First 10 Trades**")
                st.dataframe(pd.DataFrame(trades).head(10), use_container_width=True)

            # Save outputs
            import_dir = Path(__file__).parent / "imports" / (st.session_state.last_run_id or "statement")
            csv_path, json_path = save_statement_outputs(trades, summary, import_dir)

            dl_col1, dl_col2 = st.columns(2)
            with open(csv_path, "rb") as f:
                dl_col1.download_button("⬇️ statement_trades.csv", f.read(),
                                        file_name="statement_trades.csv", mime="text/csv")
            with open(json_path, "rb") as f:
                dl_col2.download_button("⬇️ statement_summary.json", f.read(),
                                        file_name="statement_summary.json", mime="application/json")
        else:
            if not summary and not trades:
                st.warning(f"⚠️ {err_msg}")
            else:
                st.info(f"Partial import: {err_msg or 'no error'}")
