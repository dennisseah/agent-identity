import re


def _escape_latex(text: str) -> str:
    """Escape special LaTeX characters."""
    text = text.replace("#", r"\#")
    text = text.replace("$", r"\$")
    text = text.replace("_", r"\_")
    text = text.replace("&", r"\&")
    text = text.replace("%", r"\%")
    return text


def _apply_formatting(text: str) -> str:
    """Apply markdown-style formatting (backtick, bold, italic)."""
    return re.sub(
        r"\*(.+?)\*",
        r"\\textit{\1}",
        re.sub(
            r"\*\*(.+?)\*\*",
            r"\\textbf{\1}",
            re.sub(r"`(.+?)`", r"\\texttt{\1}", text),
        ),
    )


def normalize_text(text: str) -> str:
    # Extract markdown links [text](url) before escaping so URLs stay intact
    links: list[tuple[str, str]] = []

    def _capture_link(match: re.Match) -> str:
        links.append((match.group(1), match.group(2)))
        return f"\x00LINK{len(links) - 1}\x00"

    text = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", _capture_link, text)

    # Extract raw LaTeX commands (e.g. \ref{...}, \label{...}) before escaping
    latex_cmds: list[str] = []

    def _capture_cmd(match: re.Match) -> str:
        latex_cmds.append(match.group(0))
        return f"\x00CMD{len(latex_cmds) - 1}\x00"

    text = re.sub(r"\\[a-zA-Z]+\{[^}]*\}", _capture_cmd, text)

    # Escape special characters and apply formatting
    text = _apply_formatting(_escape_latex(text))

    # Restore raw LaTeX command placeholders
    for idx, cmd in enumerate(latex_cmds):
        text = text.replace(f"\x00CMD{idx}\x00", cmd)

    # Restore link placeholders as \href{url}{display}
    for idx, (display, url) in enumerate(links):
        escaped_display = _apply_formatting(_escape_latex(display))
        text = text.replace(
            f"\x00LINK{idx}\x00", f"\\href{{{url}}}{{{escaped_display}}}"
        )

    return text
