from dataclasses import dataclass, field
from typing import Optional
import uuid


@dataclass
class BacktestConfig:
    symbols: list[str]
    date_range: dict  # {"from": str | None, "to": str | None}
    reverse_on_flip: bool = False
    lot_size: Optional[float] = None
    pip_value: Optional[float] = None
    spread: Optional[float] = None
    commission: Optional[float] = None
    phase: str = "Phase1-C1"
    run_id: str = field(default_factory=lambda: str(uuid.uuid4()))


@dataclass
class Position:
    symbol: str
    direction: str  # "long" or "short"
    entry_bar: int
    entry_price: float
    entry_timestamp: str


@dataclass
class Trade:
    trade_id: str
    symbol: str
    direction: str
    entry_timestamp: str
    entry_price: float
    exit_timestamp: str
    exit_price: float
    pips: float
    close_reason: str


@dataclass
class JournalEntry:
    bar: int
    timestamp: str
    symbol: str
    open: float
    high: float
    low: float
    close: float
    signal: int
    action: str
    position_direction: Optional[str]
    running_pips: float


@dataclass
class BacktestResult:
    config: BacktestConfig
    trades: list[Trade]
    journal: list[JournalEntry]
    summary: dict
