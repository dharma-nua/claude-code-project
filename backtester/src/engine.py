import uuid
import pandas as pd
from .models import (
    BacktestConfig, BacktestResult, Position, Trade, JournalEntry
)

PIP_SIZE = {
    "EURUSD": 0.0001,
    "EURGBP": 0.0001,
    "AUDNZD": 0.0001,
    "AUDCAD": 0.0001,
    "CHFJPY": 0.01,
}


class BacktestEngine:

    def run(
        self,
        candles_df: pd.DataFrame,
        signals_df: pd.DataFrame,
        config: BacktestConfig,
        log_callback=None,
    ) -> BacktestResult:
        """Run the bar-by-bar backtest simulation."""

        def log(msg: str):
            if log_callback:
                log_callback(msg)

        # Filter by selected symbols
        candles = candles_df[candles_df["symbol"].isin(config.symbols)].copy()

        # Filter by date range
        if config.date_range.get("from"):
            candles = candles[candles["timestamp"] >= config.date_range["from"]]
        if config.date_range.get("to"):
            candles = candles[candles["timestamp"] <= config.date_range["to"]]

        # Sort by (timestamp, symbol)
        candles = candles.sort_values(["timestamp", "symbol"]).reset_index(drop=True)

        # Build signal lookup: {(timestamp, symbol): signal}
        signal_lookup: dict[tuple, int] = {}
        for _, row in signals_df.iterrows():
            signal_lookup[(row["timestamp"], row["symbol"])] = int(row["signal"])

        # State: one open position per symbol
        open_positions: dict[str, Position] = {}  # symbol -> Position
        trades: list[Trade] = []
        journal: list[JournalEntry] = []

        # Track pips per symbol for running_pips
        running_pips_by_symbol: dict[str, float] = {s: 0.0 for s in config.symbols}

        # Track missing signals
        total_bars = len(candles)
        missing_signal_bars = 0
        missing_by_symbol: dict[str, int] = {s: 0 for s in config.symbols}
        total_by_symbol: dict[str, int] = {s: 0 for s in config.symbols}

        log(f"Starting simulation: {total_bars} bars across {len(config.symbols)} symbols")

        for bar_idx, row in candles.iterrows():
            ts = str(row["timestamp"])
            symbol = str(row["symbol"])
            bar_open = float(row["open"])
            bar_high = float(row["high"])
            bar_low = float(row["low"])
            bar_close = float(row["close"])
            pip_size = PIP_SIZE.get(symbol, 0.0001)

            # Look up signal
            signal_key = (ts, symbol)
            if signal_key in signal_lookup:
                signal = signal_lookup[signal_key]
            else:
                signal = 0
                missing_signal_bars += 1
                missing_by_symbol[symbol] = missing_by_symbol.get(symbol, 0) + 1

            total_by_symbol[symbol] = total_by_symbol.get(symbol, 0) + 1

            action = "HOLD"
            position = open_positions.get(symbol)

            # Apply simulation rules
            if position is None:
                # Flat
                if signal == 1:
                    action = "OPEN_LONG"
                    open_positions[symbol] = Position(
                        symbol=symbol,
                        direction="long",
                        entry_bar=bar_idx,
                        entry_price=bar_close,
                        entry_timestamp=ts,
                    )
                    log(f"  [{ts}] {symbol} OPEN_LONG @ {bar_close}")
                elif signal == -1:
                    action = "OPEN_SHORT"
                    open_positions[symbol] = Position(
                        symbol=symbol,
                        direction="short",
                        entry_bar=bar_idx,
                        entry_price=bar_close,
                        entry_timestamp=ts,
                    )
                    log(f"  [{ts}] {symbol} OPEN_SHORT @ {bar_close}")
            else:
                # In a position
                if position.direction == "long" and signal == -1:
                    # Close long
                    pips = (bar_close - position.entry_price) / pip_size
                    trade = Trade(
                        trade_id=str(uuid.uuid4()),
                        symbol=symbol,
                        direction="long",
                        entry_timestamp=position.entry_timestamp,
                        entry_price=position.entry_price,
                        exit_timestamp=ts,
                        exit_price=bar_close,
                        pips=round(pips, 2),
                        close_reason="SIGNAL_FLIP",
                    )
                    trades.append(trade)
                    running_pips_by_symbol[symbol] = running_pips_by_symbol.get(symbol, 0.0) + pips
                    log(f"  [{ts}] {symbol} CLOSE_LONG @ {bar_close} ({pips:+.2f} pips)")
                    del open_positions[symbol]
                    action = "CLOSE_LONG"

                    if config.reverse_on_flip:
                        action = "CLOSE_LONG+OPEN_SHORT"
                        open_positions[symbol] = Position(
                            symbol=symbol,
                            direction="short",
                            entry_bar=bar_idx,
                            entry_price=bar_close,
                            entry_timestamp=ts,
                        )
                        log(f"  [{ts}] {symbol} OPEN_SHORT (flip) @ {bar_close}")

                elif position.direction == "short" and signal == 1:
                    # Close short
                    pips = (position.entry_price - bar_close) / pip_size
                    trade = Trade(
                        trade_id=str(uuid.uuid4()),
                        symbol=symbol,
                        direction="short",
                        entry_timestamp=position.entry_timestamp,
                        entry_price=position.entry_price,
                        exit_timestamp=ts,
                        exit_price=bar_close,
                        pips=round(pips, 2),
                        close_reason="SIGNAL_FLIP",
                    )
                    trades.append(trade)
                    running_pips_by_symbol[symbol] = running_pips_by_symbol.get(symbol, 0.0) + pips
                    log(f"  [{ts}] {symbol} CLOSE_SHORT @ {bar_close} ({pips:+.2f} pips)")
                    del open_positions[symbol]
                    action = "CLOSE_SHORT"

                    if config.reverse_on_flip:
                        action = "CLOSE_SHORT+OPEN_LONG"
                        open_positions[symbol] = Position(
                            symbol=symbol,
                            direction="long",
                            entry_bar=bar_idx,
                            entry_price=bar_close,
                            entry_timestamp=ts,
                        )
                        log(f"  [{ts}] {symbol} OPEN_LONG (flip) @ {bar_close}")

            # Calculate running pips for journal
            current_pos = open_positions.get(symbol)
            unrealized = 0.0
            if current_pos:
                if current_pos.direction == "long":
                    unrealized = (bar_close - current_pos.entry_price) / pip_size
                else:
                    unrealized = (current_pos.entry_price - bar_close) / pip_size

            running_pips = running_pips_by_symbol.get(symbol, 0.0) + unrealized

            journal.append(JournalEntry(
                bar=bar_idx,
                timestamp=ts,
                symbol=symbol,
                open=bar_open,
                high=bar_high,
                low=bar_low,
                close=bar_close,
                signal=signal,
                action=action,
                position_direction=open_positions[symbol].direction if symbol in open_positions else None,
                running_pips=round(running_pips, 2),
            ))

        # Force-close all open positions at end of data
        # Find the last bar for each symbol
        last_bars: dict[str, dict] = {}
        for _, row in candles.iterrows():
            last_bars[str(row["symbol"])] = row

        for symbol, position in list(open_positions.items()):
            last_row = last_bars.get(symbol)
            if last_row is None:
                continue
            ts = str(last_row["timestamp"])
            bar_close = float(last_row["close"])
            pip_size = PIP_SIZE.get(symbol, 0.0001)

            if position.direction == "long":
                pips = (bar_close - position.entry_price) / pip_size
            else:
                pips = (position.entry_price - bar_close) / pip_size

            trade = Trade(
                trade_id=str(uuid.uuid4()),
                symbol=symbol,
                direction=position.direction,
                entry_timestamp=position.entry_timestamp,
                entry_price=position.entry_price,
                exit_timestamp=ts,
                exit_price=bar_close,
                pips=round(pips, 2),
                close_reason="END_OF_DATA",
            )
            trades.append(trade)
            log(f"  [END] {symbol} force-close {position.direction.upper()} @ {bar_close} ({pips:+.2f} pips)")

        log(f"Simulation complete: {len(trades)} trades, {total_bars} bars processed")

        # Compute summary
        summary = self._compute_summary(
            trades=trades,
            total_bars=total_bars,
            missing_signal_bars=missing_signal_bars,
            total_by_symbol=total_by_symbol,
            missing_by_symbol=missing_by_symbol,
        )

        return BacktestResult(
            config=config,
            trades=trades,
            journal=journal,
            summary=summary,
        )

    def _compute_summary(
        self,
        trades: list[Trade],
        total_bars: int,
        missing_signal_bars: int,
        total_by_symbol: dict[str, int],
        missing_by_symbol: dict[str, int],
    ) -> dict:
        total_trades = len(trades)
        winning = [t for t in trades if t.pips > 0]
        losing = [t for t in trades if t.pips <= 0]
        win_count = len(winning)
        loss_count = len(losing)
        win_rate = win_count / total_trades if total_trades > 0 else 0.0
        total_pips = sum(t.pips for t in trades)
        avg_pips = total_pips / total_trades if total_trades > 0 else 0.0
        avg_win = sum(t.pips for t in winning) / win_count if win_count > 0 else 0.0
        avg_loss = sum(t.pips for t in losing) / loss_count if loss_count > 0 else 0.0

        gross_profit = sum(t.pips for t in winning)
        gross_loss = abs(sum(t.pips for t in losing))
        profit_factor = gross_profit / gross_loss if gross_loss > 0 else None

        # Max drawdown: running pip curve minimum
        running = 0.0
        peak = 0.0
        max_dd = 0.0
        for t in trades:
            running += t.pips
            if running > peak:
                peak = running
            dd = peak - running
            if dd > max_dd:
                max_dd = dd

        missing_signal_rate = missing_signal_bars / total_bars if total_bars > 0 else 0.0

        # Per-symbol breakdown
        symbols_in_trades = set(t.symbol for t in trades)
        per_symbol = {}
        for sym in set(list(symbols_in_trades) + list(total_by_symbol.keys())):
            sym_trades = [t for t in trades if t.symbol == sym]
            sym_winning = [t for t in sym_trades if t.pips > 0]
            sym_total_bars = total_by_symbol.get(sym, 0)
            sym_missing = missing_by_symbol.get(sym, 0)
            per_symbol[sym] = {
                "total_trades": len(sym_trades),
                "winning_trades": len(sym_winning),
                "total_pips": round(sum(t.pips for t in sym_trades), 2),
                "win_rate": len(sym_winning) / len(sym_trades) if sym_trades else 0.0,
                "missing_signal_rate": sym_missing / sym_total_bars if sym_total_bars > 0 else 0.0,
            }

        return {
            "total_trades": total_trades,
            "winning_trades": win_count,
            "losing_trades": loss_count,
            "win_rate": round(win_rate, 4),
            "total_pips": round(total_pips, 2),
            "avg_pips_per_trade": round(avg_pips, 2),
            "avg_win_pips": round(avg_win, 2),
            "avg_loss_pips": round(avg_loss, 2),
            "profit_factor": round(profit_factor, 4) if profit_factor is not None else None,
            "max_drawdown_pips": round(max_dd, 2),
            "missing_signal_rate": round(missing_signal_rate, 4),
            "per_symbol": per_symbol,
        }
