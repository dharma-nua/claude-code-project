import os
import json
import tempfile
from datetime import date
import streamlit as st
import pandas as pd

from src.parser import parse_candles, parse_signals
from src.validator import validate_candles, validate_signals, validate_alignment
from src.engine import BacktestEngine
from src.models import BacktestConfig
from src.reporter import generate_outputs

st.set_page_config(
    page_title="Backtester — Phase 1",
    page_icon="📈",
    layout="wide",
)

st.title("📈 Phase 1 Backtester — C1-Only Engine")

# ─── Session state initialization ───────────────────────────────────────────
if "candles_df" not in st.session_state:
    st.session_state.candles_df = None
if "signals_df" not in st.session_state:
    st.session_state.signals_df = None
if "candles_valid" not in st.session_state:
    st.session_state.candles_valid = False
if "signals_valid" not in st.session_state:
    st.session_state.signals_valid = False
if "backtest_result" not in st.session_state:
    st.session_state.backtest_result = None
if "output_paths" not in st.session_state:
    st.session_state.output_paths = None
if "run_log" not in st.session_state:
    st.session_state.run_log = []

ALLOWED_SYMBOLS = ["EURUSD", "EURGBP", "AUDNZD", "AUDCAD", "CHFJPY"]

tab_upload, tab_indicators, tab_setup, tab_run, tab_results = st.tabs([
    "📂 Upload Data",
    "📚 Indicator Library",
    "⚙️ Setup",
    "▶️ Run",
    "📊 Results",
])

# ═══════════════════════════════════════════════════════════════════════
# TAB 1 — Upload Data
# ═══════════════════════════════════════════════════════════════════════
with tab_upload:
    st.subheader("Upload Data Files")
    st.caption("Upload your candles and signals CSVs. Files are validated immediately on upload.")

    col_c, col_s = st.columns(2)

    with col_c:
        st.markdown("**Candles CSV**")
        st.caption("Required columns: timestamp, symbol, timeframe, open, high, low, close, volume")
        candles_file = st.file_uploader("Upload candles CSV", type="csv", key="candles_uploader")

        if candles_file:
            try:
                df = parse_candles(candles_file)
                ok, errors = validate_candles(df)
                if ok:
                    st.session_state.candles_df = df
                    st.session_state.candles_valid = True
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

    # Alignment warnings (only when both are valid)
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

    indicators = [
        ("C1", "Confirmation Indicator 1", True, "Active"),
        ("C2", "Confirmation Indicator 2", False, "Coming in future phase"),
        ("Vol", "Volatility Filter", False, "Coming in future phase"),
        ("Exit", "Exit Indicator", False, "Coming in future phase"),
        ("Baseline", "Baseline Trend Filter", False, "Coming in future phase"),
    ]

    for code, name, active, tooltip in indicators:
        col_a, col_b, col_c = st.columns([1, 4, 3])
        with col_a:
            if active:
                st.markdown(f"**{code}**")
            else:
                st.markdown(f"<span style='color:#666'>{code}</span>", unsafe_allow_html=True)
        with col_b:
            if active:
                st.markdown(f"**{name}**")
            else:
                st.markdown(f"<span style='color:#666'>{name}</span>", unsafe_allow_html=True)
        with col_c:
            if active:
                st.success("✅ Active")
            else:
                st.caption(f"🔒 {tooltip}")


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
            date_from = st.date_input(
                "Date From (optional)",
                value=None,
                help="Leave blank to use the earliest available date.",
            )
        with col_d2:
            date_to = st.date_input(
                "Date To (optional)",
                value=None,
                help="Leave blank to use the latest available date.",
            )

        reverse_on_flip = st.toggle(
            "Reverse on Flip",
            value=False,
            help="When enabled: closing a long automatically opens a short (and vice versa). Default OFF — close only.",
        )

    with col_right:
        with st.expander("Reserved Fields (not used in P&L yet)", expanded=False):
            lot_size = st.number_input("Lot Size", min_value=0.0, value=0.0, step=0.01,
                                       help="Stored but not used in Phase 1 calculations.")
            pip_value = st.number_input("Pip Value ($)", min_value=0.0, value=0.0, step=0.01,
                                        help="Stored but not used in Phase 1 calculations.")
            spread = st.number_input("Spread (pips)", min_value=0.0, value=0.0, step=0.1,
                                     help="Stored but not used in Phase 1 calculations.")
            commission = st.number_input("Commission per trade ($)", min_value=0.0, value=0.0, step=0.01,
                                         help="Stored but not used in Phase 1 calculations.")

    # Store config in session state for Run tab to use
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

        # ── Summary cards ──────────────────────────────────────────────
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

        # ── Trades table ──────────────────────────────────────────────
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

        # ── Journal table ─────────────────────────────────────────────
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

        # ── Downloads ─────────────────────────────────────────────────
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
