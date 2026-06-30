#!/usr/bin/env python3
"""Generate offline HTML and Markdown reports from a TRE Research SQLite DB."""

from __future__ import annotations

import argparse
import atexit
import csv
import html
import os
import shutil
import sqlite3
import sys
from pathlib import Path
from urllib.parse import quote

try:
    import pandas as pd
except ImportError as exc:  # pragma: no cover - depends on user environment
    print(
        "Missing dependency: pandas. Install dependencies first "
        "(python -m pip install pandas matplotlib).",
        file=sys.stderr,
    )
    raise SystemExit(2) from exc


REPORT_TITLE = "Trading Rule Engine Research Report"
MAX_TABLE_ROWS = 200
plt = None


def configure_matplotlib(output_dir: Path) -> None:
    """Load matplotlib lazily and keep its cache out of the repository."""
    global plt
    if plt is not None:
        return

    if "MPLCONFIGDIR" not in os.environ:
        cache_dir = output_dir / ".tre-matplotlib-cache"
        created_cache = not cache_dir.exists()
        cache_dir.mkdir(parents=True, exist_ok=True)
        os.environ["MPLCONFIGDIR"] = str(cache_dir)
        if created_cache:
            atexit.register(shutil.rmtree, cache_dir, ignore_errors=True)

    try:
        import matplotlib

        matplotlib.use("Agg")
        import matplotlib.pyplot as pyplot
    except ImportError as exc:  # pragma: no cover - depends on user environment
        raise RuntimeError(
            "Missing dependency: matplotlib. Install dependencies with "
            "'python -m pip install pandas matplotlib'."
        ) from exc
    plt = pyplot


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate an offline report from a TRE_RESEARCH SQLite DB."
    )
    parser.add_argument("--db", required=True, type=Path, help="Input SQLite .db file")
    parser.add_argument(
        "--out",
        required=True,
        type=Path,
        help="Output folder for report.html, report.md, and charts",
    )
    parser.add_argument(
        "--summary-csv",
        action="store_true",
        help="Also create report_summary.csv",
    )
    return parser.parse_args()


def open_read_only(db_path: Path) -> sqlite3.Connection:
    resolved = db_path.expanduser().resolve()
    if not resolved.is_file():
        raise FileNotFoundError(f"Database file does not exist: {resolved}")

    sqlite_path = quote(resolved.as_posix(), safe="/:")
    connection = sqlite3.connect(f"file:{sqlite_path}?mode=ro", uri=True)
    connection.execute("PRAGMA query_only=ON")
    return connection


def relation_names(connection: sqlite3.Connection) -> set[str]:
    rows = connection.execute(
        "SELECT name FROM sqlite_master WHERE type IN ('table','view')"
    ).fetchall()
    return {str(row[0]) for row in rows}


def read_relation(
    connection: sqlite3.Connection,
    available: set[str],
    name: str,
    warnings: list[str],
) -> pd.DataFrame:
    if name not in available:
        warnings.append(f"Missing view/table: {name}; related section was skipped.")
        return pd.DataFrame()
    try:
        return pd.read_sql_query(f'SELECT * FROM "{name}"', connection)
    except (sqlite3.Error, pd.errors.DatabaseError) as exc:
        warnings.append(f"Could not read {name}: {exc}")
        return pd.DataFrame()


def number_series(frame: pd.DataFrame, column: str) -> pd.Series:
    if column not in frame.columns:
        return pd.Series(0.0, index=frame.index, dtype=float)
    return pd.to_numeric(frame[column], errors="coerce").fillna(0.0)


def scalar(frame: pd.DataFrame, column: str, default: object = "N/A") -> object:
    if frame.empty or column not in frame.columns:
        return default
    value = frame.iloc[0][column]
    return default if pd.isna(value) else value


def display_value(value: object) -> str:
    if value is None or (isinstance(value, float) and pd.isna(value)):
        return "N/A"
    if isinstance(value, float):
        return f"{value:,.2f}"
    return str(value)


def markdown_escape(value: object) -> str:
    return (
        display_value(value)
        .replace("|", r"\|")
        .replace("\r", " ")
        .replace("\n", " ")
    )


def markdown_table(frame: pd.DataFrame, max_rows: int = MAX_TABLE_ROWS) -> str:
    if frame.empty:
        return "_No data available._"

    shown = frame.head(max_rows)
    headers = [markdown_escape(column) for column in shown.columns]
    lines = [
        "| " + " | ".join(headers) + " |",
        "| " + " | ".join("---" for _ in headers) + " |",
    ]
    for row in shown.itertuples(index=False, name=None):
        lines.append("| " + " | ".join(markdown_escape(value) for value in row) + " |")
    if len(frame) > max_rows:
        lines.append(f"\n_Showing {max_rows} of {len(frame)} rows._")
    return "\n".join(lines)


def html_table(frame: pd.DataFrame, max_rows: int = MAX_TABLE_ROWS) -> str:
    if frame.empty:
        return '<p class="empty">No data available.</p>'
    shown = frame.head(max_rows)
    table = shown.to_html(
        index=False,
        border=0,
        classes="data-table",
        na_rep="N/A",
        float_format=lambda value: f"{value:,.2f}",
        escape=True,
    )
    if len(frame) > max_rows:
        table += f"<p>Showing {max_rows} of {len(frame)} rows.</p>"
    return table


def overview_frame(values: list[tuple[str, object]]) -> pd.DataFrame:
    return pd.DataFrame(values, columns=["Metric", "Value"])


def sum_column(frame: pd.DataFrame, column: str) -> float:
    return float(number_series(frame, column).sum()) if not frame.empty else 0.0


def build_run_overview(
    experiment: pd.DataFrame,
    signal: pd.DataFrame,
    trade_open: pd.DataFrame,
    trade_close: pd.DataFrame,
    trade_summary: pd.DataFrame,
) -> tuple[pd.DataFrame, dict[str, object]]:
    total_signals = len(signal)
    trades_opened = (
        int(number_series(signal, "is_trade_opened").sum())
        if not signal.empty and "is_trade_opened" in signal.columns
        else len(trade_open)
    )
    trades_closed = int(scalar(trade_summary, "closed_trades", len(trade_close)))
    win_count = int(scalar(trade_summary, "win_count", 0))
    win_rate = (win_count / trades_closed * 100.0) if trades_closed else 0.0
    net_profit = float(scalar(trade_summary, "net_profit", 0.0))
    profit_factor = scalar(trade_summary, "profit_factor", "N/A")
    avg_mae = scalar(trade_summary, "avg_mae", 0.0)
    avg_mfe = scalar(trade_summary, "avg_mfe", 0.0)

    values: list[tuple[str, object]] = [
        ("Experiment ID", scalar(experiment, "experiment_id")),
        ("Symbol", scalar(experiment, "symbol")),
        ("Created At", scalar(experiment, "created_at")),
        ("Execution Mode", scalar(experiment, "execution_mode")),
        ("Manual Profile", scalar(experiment, "manual_profile")),
        ("Zone / Bias TF", f"{scalar(experiment, 'zone_tf')} / {scalar(experiment, 'bias_tf')}"),
        (
            "Entry / Execution TF",
            f"{scalar(experiment, 'entry_tf')} / {scalar(experiment, 'execution_tf')}",
        ),
        (
            "Regime Detection / Auto Switch",
            f"{scalar(experiment, 'use_auto_regime_detection')} / "
            f"{scalar(experiment, 'allow_auto_profile_switch')}",
        ),
        ("Regime TF / Lookback", f"{scalar(experiment, 'regime_tf')} / {scalar(experiment, 'regime_lookback_bars')}"),
        ("Pressure Guard / Mode", f"{scalar(experiment, 'use_pressure_guard')} / {scalar(experiment, 'pressure_guard_mode')}"),
        ("Pressure TF / Lookback", f"{scalar(experiment, 'pressure_tf')} / {scalar(experiment, 'pressure_lookback_bars')}"),
        (
            "Pressure Medium / High Threshold",
            f"{scalar(experiment, 'pressure_medium_threshold')} / "
            f"{scalar(experiment, 'pressure_high_threshold')}",
        ),
        (
            "Pressure Medium / High Penalty",
            f"{scalar(experiment, 'pressure_medium_penalty')} / "
            f"{scalar(experiment, 'pressure_high_penalty')}",
        ),
        ("Total Signals", total_signals),
        ("Trades Opened", trades_opened),
        ("Trades Closed", trades_closed),
        ("Win Rate", f"{win_rate:.2f}%"),
        ("Net Profit", net_profit),
        ("Profit Factor", profit_factor),
        ("Average MAE", avg_mae),
        ("Average MFE", avg_mfe),
    ]
    summary = {
        "experiment_id": scalar(experiment, "experiment_id"),
        "symbol": scalar(experiment, "symbol"),
        "total_signals": total_signals,
        "trades_opened": trades_opened,
        "trades_closed": trades_closed,
        "win_rate_percent": round(win_rate, 4),
        "net_profit": net_profit,
        "profit_factor": profit_factor,
        "avg_mae": avg_mae,
        "avg_mfe": avg_mfe,
    }
    return overview_frame(values), summary


def aggregate_pressure_level(policy: pd.DataFrame) -> pd.DataFrame:
    if policy.empty or "pressure_level" not in policy.columns:
        return pd.DataFrame()
    work = policy.copy()
    for column in ("signal_count", "trade_count", "win_count", "loss_count", "net_profit"):
        work[column] = number_series(work, column)
    grouped = (
        work.groupby("pressure_level", dropna=False)[
            ["signal_count", "trade_count", "win_count", "loss_count", "net_profit"]
        ]
        .sum()
        .reset_index()
    )
    grouped["win_rate_percent"] = (
        grouped["win_count"]
        .div(grouped["win_count"] + grouped["loss_count"])
        .where((grouped["win_count"] + grouped["loss_count"]) > 0, 0)
        * 100
    )
    return grouped


def aggregate_pressure_action(policy: pd.DataFrame) -> pd.DataFrame:
    if policy.empty or "pressure_action" not in policy.columns:
        return pd.DataFrame()
    work = policy.copy()
    for column in ("signal_count", "trade_count", "win_count", "loss_count", "net_profit"):
        work[column] = number_series(work, column)
    return (
        work.groupby("pressure_action", dropna=False)[
            ["signal_count", "trade_count", "win_count", "loss_count", "net_profit"]
        ]
        .sum()
        .reset_index()
    )


def add_regime_win_rate(frame: pd.DataFrame) -> pd.DataFrame:
    if frame.empty:
        return frame
    result = frame.copy()
    wins = number_series(result, "win_count")
    losses = number_series(result, "loss_count")
    result["win_rate_percent"] = wins.div(wins + losses).where((wins + losses) > 0, 0) * 100
    return result


def dangerous_zone_combinations(matrix: pd.DataFrame) -> pd.DataFrame:
    if matrix.empty:
        return matrix
    trades = number_series(matrix, "trade_count")
    wins = number_series(matrix, "win_count")
    losses = number_series(matrix, "loss_count")
    profit = number_series(matrix, "net_profit")
    return matrix[(trades >= 5) & (profit < 0) & (losses > wins)].copy()


def save_bar_chart(
    frame: pd.DataFrame,
    label_column: str,
    value_column: str,
    title: str,
    ylabel: str,
    output: Path,
    color: str = "#3b82f6",
) -> bool:
    if frame.empty or label_column not in frame.columns or value_column not in frame.columns:
        return False
    values = pd.to_numeric(frame[value_column], errors="coerce").fillna(0)
    labels = frame[label_column].fillna("N/A").astype(str)
    if len(labels) == 0:
        return False

    width = max(7.0, min(16.0, len(labels) * 0.75))
    fig, axis = plt.subplots(figsize=(width, 4.8))
    axis.bar(labels, values, color=color)
    axis.set_title(title)
    axis.set_ylabel(ylabel)
    axis.axhline(0, color="#333333", linewidth=0.8)
    axis.tick_params(axis="x", rotation=35)
    fig.tight_layout()
    fig.savefig(output, dpi=140, bbox_inches="tight")
    plt.close(fig)
    return True


def chart_zone_pressure(matrix: pd.DataFrame, output: Path) -> bool:
    if matrix.empty:
        return False
    needed = {
        "zone_id",
        "candidate_direction_before_pressure",
        "pressure_direction",
        "pressure_level",
        "net_profit",
    }
    if not needed.issubset(matrix.columns):
        return False
    work = matrix.copy()
    work["combination"] = (
        "Z"
        + work["zone_id"].fillna("N/A").astype(str)
        + " "
        + work["candidate_direction_before_pressure"].fillna("NONE").astype(str)
        + " / "
        + work["pressure_direction"].fillna("NONE").astype(str)
        + " "
        + work["pressure_level"].fillna("NONE").astype(str)
    )
    work = work.sort_values("net_profit").head(30)
    return save_bar_chart(
        work,
        "combination",
        "net_profit",
        "Net Profit by Zone + Pressure (lowest 30)",
        "Net Profit",
        output,
        color="#f59e0b",
    )


def saved_missed_counts(saved_missed: pd.DataFrame) -> pd.DataFrame:
    if saved_missed.empty or "pressure_shadow_result" not in saved_missed.columns:
        return pd.DataFrame(columns=["pressure_shadow_result", "count"])
    return (
        saved_missed["pressure_shadow_result"]
        .fillna("UNKNOWN")
        .value_counts()
        .rename_axis("pressure_shadow_result")
        .reset_index(name="count")
    )


def build_analyst_notes(
    saved_missed: pd.DataFrame,
    dangerous: pd.DataFrame,
    best_practice: pd.DataFrame,
    trades_closed: int,
) -> list[str]:
    notes: list[str] = []
    counts = saved_missed_counts(saved_missed)
    count_map = (
        dict(zip(counts["pressure_shadow_result"], counts["count"]))
        if not counts.empty
        else {}
    )
    saved = int(count_map.get("SAVED_LOSS", 0))
    missed = int(count_map.get("MISSED_WIN", 0))

    if saved + missed == 0:
        notes.append(
            "Not enough closed pressure-warning trades exist to judge whether "
            "Pressure should become a governing layer."
        )
    elif saved > missed:
        notes.append(
            f"Pressure appears potentially helpful: {saved} warned losing trades "
            f"versus {missed} warned winning trades. Validate with a larger sample."
        )
    elif missed > saved:
        notes.append(
            f"Pressure currently shows dangerous false positives: {missed} warned "
            f"winning trades versus {saved} warned losing trades."
        )
    else:
        notes.append(
            "Pressure saved-loss and missed-win counts are balanced; the evidence "
            "does not yet support promotion to a governing policy."
        )

    if dangerous.empty:
        notes.append(
            "No zone + pressure combination currently meets the dangerous threshold "
            "(at least 5 trades, negative net profit, and more losses than wins)."
        )
    else:
        labels: list[str] = []
        for _, row in dangerous.head(5).iterrows():
            labels.append(
                f"Zone {display_value(row.get('zone_id'))} "
                f"{display_value(row.get('candidate_direction_before_pressure'))} + "
                f"{display_value(row.get('pressure_direction'))} "
                f"{display_value(row.get('pressure_level'))}"
            )
        notes.append("Combinations to investigate or avoid: " + "; ".join(labels) + ".")

    if not best_practice.empty and "suggested_action" in best_practice.columns:
        need_more = int((best_practice["suggested_action"] == "NEED_MORE_DATA").sum())
        avoid = int((best_practice["suggested_action"] == "AVOID_OR_BLOCK").sum())
        promote = int((best_practice["suggested_action"] == "ALLOW_OR_PROMOTE").sum())
        notes.append(
            f"Rule candidates: {avoid} avoid/block, {promote} allow/promote, "
            f"and {need_more} needing more data."
        )

    if trades_closed == 0:
        notes.append(
            "No closed trades are available. The report therefore summarizes signals "
            "only; profitability, MAE, and MFE conclusions are premature."
        )
    elif trades_closed < 30:
        notes.append(
            f"Only {trades_closed} trades are closed. Continue the same controlled "
            "test until at least 30 closed trades before changing policy."
        )

    notes.append(
        "Next test: keep Entry and Execution unchanged, collect more HIGH/MEDIUM "
        "opposing-pressure samples, then compare saved losses, missed wins, profit "
        "factor, and MAE/MFE by zone and regime."
    )
    return notes


def chart_markup(filename: str, alt: str) -> tuple[str, str]:
    markdown = f"![{alt}]({filename})"
    html_text = (
        f'<figure><img src="{html.escape(filename)}" alt="{html.escape(alt)}">'
        f"<figcaption>{html.escape(alt)}</figcaption></figure>"
    )
    return markdown, html_text


def write_summary_csv(path: Path, summary: dict[str, object]) -> None:
    with path.open("w", newline="", encoding="utf-8-sig") as handle:
        writer = csv.writer(handle)
        writer.writerow(["metric", "value"])
        for key, value in summary.items():
            writer.writerow([key, display_value(value)])


def generate_report(db_path: Path, output_dir: Path, summary_csv: bool) -> None:
    warnings: list[str] = []
    output_dir.mkdir(parents=True, exist_ok=True)
    configure_matplotlib(output_dir)

    with open_read_only(db_path) as connection:
        available = relation_names(connection)
        experiment = read_relation(connection, available, "experiment", warnings)
        if not experiment.empty and "experiment_id" in experiment.columns:
            experiment = experiment.sort_values("experiment_id", ascending=False).head(1)

        signal = read_relation(connection, available, "signal", warnings)
        trade_open = read_relation(connection, available, "trade_open", warnings)
        trade_close = read_relation(connection, available, "trade_close", warnings)
        trade_summary = read_relation(
            connection, available, "v_trade_performance_summary", warnings
        )
        policy_summary = read_relation(
            connection, available, "v_pressure_policy_summary", warnings
        )
        saved_missed = read_relation(
            connection, available, "v_pressure_saved_or_missed", warnings
        )
        shadow_value = read_relation(
            connection, available, "v_pressure_shadow_value", warnings
        )
        risk_matrix = read_relation(
            connection, available, "v_pressure_zone_risk_matrix", warnings
        )
        zone_pressure = read_relation(
            connection, available, "v_zone_pressure_performance", warnings
        )
        regime = read_relation(connection, available, "v_regime_performance", warnings)
        best_practice = read_relation(
            connection, available, "v_best_practice_candidate", warnings
        )

    overview, summary = build_run_overview(
        experiment, signal, trade_open, trade_close, trade_summary
    )
    level_summary = aggregate_pressure_level(policy_summary)
    action_summary = aggregate_pressure_action(policy_summary)
    shadow_counts = saved_missed_counts(saved_missed)
    regime_report = add_regime_win_rate(regime)
    dangerous = dangerous_zone_combinations(risk_matrix)

    charts: list[tuple[str, str]] = []
    chart_specs = [
        (
            save_bar_chart(
                level_summary,
                "pressure_level",
                "net_profit",
                "Profit by Pressure Level",
                "Net Profit",
                output_dir / "profit_by_pressure_level.png",
            ),
            "profit_by_pressure_level.png",
            "Profit by pressure level",
        ),
        (
            save_bar_chart(
                action_summary,
                "pressure_action",
                "trade_count",
                "Trade Count by Pressure Action",
                "Trade Count",
                output_dir / "trade_count_by_pressure_action.png",
                color="#10b981",
            ),
            "trade_count_by_pressure_action.png",
            "Trade count by pressure action",
        ),
        (
            chart_zone_pressure(
                risk_matrix, output_dir / "net_profit_by_zone_pressure.png"
            ),
            "net_profit_by_zone_pressure.png",
            "Net profit by zone and pressure",
        ),
        (
            save_bar_chart(
                shadow_counts[
                    shadow_counts["pressure_shadow_result"].isin(
                        ["SAVED_LOSS", "MISSED_WIN"]
                    )
                ],
                "pressure_shadow_result",
                "count",
                "Saved Loss vs Missed Win",
                "Count",
                output_dir / "saved_loss_vs_missed_win.png",
                color="#8b5cf6",
            ),
            "saved_loss_vs_missed_win.png",
            "Saved loss versus missed win",
        ),
    ]
    charts.extend((filename, alt) for created, filename, alt in chart_specs if created)

    notes = build_analyst_notes(
        saved_missed,
        dangerous,
        best_practice,
        int(summary["trades_closed"]),
    )

    sections: list[tuple[str, pd.DataFrame | None, str | None]] = [
        ("1. Run Overview", overview, None),
        ("2. Trade Performance", trade_summary, None),
        ("3.1 Pressure Policy Summary", policy_summary, None),
        ("3.2 Pressure Saved Loss / Missed Win", saved_missed, None),
        ("3.3 Pressure Shadow Value", shadow_value, None),
        ("3.4 Net Result by Pressure Level", level_summary, None),
        ("3.5 Performance by Pressure Action", action_summary, None),
        ("4.1 Zone + Pressure Risk Matrix", risk_matrix, None),
        ("4.2 Dangerous Combinations", dangerous, None),
        ("4.3 Legacy Zone + Pressure Performance", zone_pressure, None),
        ("5. Regime Performance", regime_report, None),
        ("6. Best Practice Candidates", best_practice, None),
    ]

    markdown_parts = [
        f"# {REPORT_TITLE}",
        "",
        f"- Database: `{db_path.expanduser().resolve()}`",
        f"- Output: `{output_dir.resolve()}`",
        "",
    ]
    html_parts = [
        "<!doctype html><html><head><meta charset=\"utf-8\">",
        f"<title>{html.escape(REPORT_TITLE)}</title>",
        """<style>
body{font-family:Arial,sans-serif;margin:0;background:#f5f7fb;color:#1f2937}
main{max-width:1280px;margin:auto;padding:28px}
h1,h2{color:#111827}section{background:white;padding:20px;margin:18px 0;
border-radius:9px;box-shadow:0 1px 4px #0002;overflow-x:auto}
.data-table{border-collapse:collapse;width:100%;font-size:13px}
.data-table th,.data-table td{border:1px solid #d1d5db;padding:7px;text-align:left}
.data-table th{background:#e5e7eb;position:sticky;top:0}
.warning{background:#fff7ed;border-left:4px solid #f97316;padding:10px}
.empty{color:#6b7280;font-style:italic}figure{text-align:center}
figure img{max-width:100%;height:auto}figcaption{color:#6b7280;font-size:13px}
li{margin:7px 0}
</style></head><body><main>""",
        f"<h1>{html.escape(REPORT_TITLE)}</h1>",
        f"<p><strong>Database:</strong> {html.escape(str(db_path.expanduser().resolve()))}</p>",
    ]

    if warnings:
        markdown_parts.extend(["## Warnings", ""])
        markdown_parts.extend(f"- {warning}" for warning in warnings)
        markdown_parts.append("")
        html_parts.append('<section><h2>Warnings</h2><ul class="warning">')
        html_parts.extend(f"<li>{html.escape(warning)}</li>" for warning in warnings)
        html_parts.append("</ul></section>")

    for title, frame, text in sections:
        markdown_parts.extend([f"## {title}", ""])
        html_parts.append(f"<section><h2>{html.escape(title)}</h2>")
        if frame is not None:
            markdown_parts.extend([markdown_table(frame), ""])
            html_parts.append(html_table(frame))
        if text:
            markdown_parts.extend([text, ""])
            html_parts.append(f"<p>{html.escape(text)}</p>")
        html_parts.append("</section>")

    markdown_parts.extend(["## Charts", ""])
    html_parts.append("<section><h2>Charts</h2>")
    if charts:
        for filename, alt in charts:
            markdown_chart, html_chart = chart_markup(filename, alt)
            markdown_parts.extend([markdown_chart, ""])
            html_parts.append(html_chart)
    else:
        markdown_parts.extend(["_No chart data available._", ""])
        html_parts.append('<p class="empty">No chart data available.</p>')
    html_parts.append("</section>")

    markdown_parts.extend(["## 7. Analyst Notes", ""])
    markdown_parts.extend(f"- {note}" for note in notes)
    markdown_parts.append("")
    html_parts.append("<section><h2>7. Analyst Notes</h2><ul>")
    html_parts.extend(f"<li>{html.escape(note)}</li>" for note in notes)
    html_parts.append("</ul></section>")

    html_parts.append("</main></body></html>")
    (output_dir / "report.md").write_text(
        "\n".join(markdown_parts), encoding="utf-8"
    )
    (output_dir / "report.html").write_text(
        "\n".join(html_parts), encoding="utf-8"
    )
    if summary_csv:
        write_summary_csv(output_dir / "report_summary.csv", summary)


def main() -> int:
    args = parse_args()
    try:
        generate_report(args.db, args.out, args.summary_csv)
    except (FileNotFoundError, sqlite3.Error, OSError, RuntimeError) as exc:
        print(f"Research report generation failed: {exc}", file=sys.stderr)
        return 1
    print(f"Created: {(args.out / 'report.html').resolve()}")
    print(f"Created: {(args.out / 'report.md').resolve()}")
    if args.summary_csv:
        print(f"Created: {(args.out / 'report_summary.csv').resolve()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
