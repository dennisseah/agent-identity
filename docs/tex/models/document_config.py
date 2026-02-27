from datetime import datetime

import yaml
from pydantic import BaseModel
from pylatex import Command, Document, NoEscape

from docs import ARTIFACT_DIR
from docs.tex import normalize_text
from docs.tex.models.document_content import DocumentContent


class GeometryOptions(BaseModel):
    top: str
    bottom: str
    left: str
    right: str


class RevisionEntry(BaseModel):
    version: str
    date: str
    description: list[str]

    @classmethod
    def render(cls, doc: Document, revisions: list["RevisionEntry"]) -> None:
        if revisions:
            doc.append(NoEscape(r"\vspace{1em}"))
            doc.append(NoEscape("\n"))
            doc.append(NoEscape(r"\begin{center}\textit{Revision History}\end{center}"))
            doc.append(NoEscape("\n"))
            doc.append(NoEscape(r"\begin{center}"))
            doc.append(NoEscape(r"\small"))
            doc.append(NoEscape(r"\renewcommand{\arraystretch}{1.75}"))
            doc.append(NoEscape(r"\begin{tabular}{@{}rll@{}}"))
            doc.append(
                NoEscape(r"\textit{Version} & \textit{Date} & \textit{Description} \\")
            )
            doc.append(NoEscape(r"\hline"))
            for rev in revisions:
                doc.append(
                    NoEscape(
                        f"{rev.version} & {rev.date} & {normalize_text(rev.description[0])} \\\\"  # noqa: E501
                    )
                )
                for desc in rev.description[1:]:
                    doc.append(NoEscape(f"& & {normalize_text(desc)} \\\\"))
            doc.append(NoEscape(r"\end{tabular}"))
            doc.append(NoEscape(r"\end{center}"))
            doc.append(NoEscape("\n"))
            doc.append(NoEscape(r"\newpage"))


class DocumentConfig(BaseModel):
    title: str
    author: list[str]
    affiliation: str
    email_domain: str | None = None
    output_file: str
    geometry_options: GeometryOptions
    preamble: list[str]
    content: list[str]
    abstract: str
    revision_history: list[RevisionEntry] = []

    @property
    def version(self) -> str:
        if self.revision_history:
            return self.revision_history[-1].version

        return "0.1.0"

    @property
    def latest_date(self) -> str:
        if self.revision_history:
            raw = self.revision_history[-1].date
            return datetime.strptime(raw, "%Y-%m-%d").strftime("%B %d, %Y")

        return r"\today"

    def create_page_title(self, doc: Document) -> None:
        # Left-align maketitle with barcode image on the right
        maketitle_def = "\n".join(
            [
                r"\makeatletter",
                r"\renewcommand{\maketitle}{%",
                r"  \bgroup\setlength{\parindent}{0pt}%",
                r"  \noindent",
                r"  \begin{minipage}[t]{0.7\textwidth}",
                r"    \vspace{0pt}%",
                r"    \raggedright",
                r"    {\Large \@title}\\[1em]",
                r"    \@author\\[1em]",
                r"    \@date",
                r"  \end{minipage}%",
                r"  \hfill",
                r"  \begin{minipage}[t]{0.25\textwidth}",
                r"    \vspace{0pt}%",
                r"    \raggedleft",
                r"    \includegraphics[width=0.75\textwidth]{docs/images/barcode.png}",
                r"  \end{minipage}",
                r"  \egroup",
                r"  \vspace{2em}",
                r"}",
                r"\makeatother",
            ]
        )
        doc.preamble.append(NoEscape(maketitle_def))

        doc.preamble.append(Command("title", self.title))

        # Format authors: name (email), joined with \\ instead of \and
        formatted_authors = []
        for a in self.author:
            # If author contains a pipe, split into name|alias
            if "|" in a:
                name, alias = a.split("|", 1)
                email = alias.strip()
                if self.email_domain:
                    email += "@" + self.email_domain
                formatted_authors.append(
                    r"\textit{" + name.strip() + r"} (" + email + ")"
                )
            else:
                formatted_authors.append(r"\textit{" + a + "}")

        authors = r" \\ ".join(formatted_authors)
        doc.preamble.append(Command("author", NoEscape(authors)))

        # Include affiliation in the date field
        date_content = (
            r"{\large \textit{"
            + self.affiliation
            + r"}}\\[2em]\textit{"
            + self.latest_date
            + r"}\\[0.5em]\textit{Version "
            + self.version
            + "}"
        )
        doc.preamble.append(
            Command(
                "date",
                NoEscape(date_content),
            )
        )
        doc.append(NoEscape(r"\maketitle"))

    def execute(self) -> Document:
        doc = Document(
            documentclass="extarticle",
            document_options=["9pt"],
            geometry_options={
                "top": self.geometry_options.top,
                "bottom": self.geometry_options.bottom,
                "left": self.geometry_options.left,
                "right": self.geometry_options.right,
            },
        )
        for pre in self.preamble:
            doc.preamble.append(NoEscape(pre))

        # Set header left to document title (italic)
        doc.preamble.append(
            NoEscape(r"\fancyhead[L]{\small \textit{" + self.title + "}}")
        )
        self.create_page_title(doc)

        doc.append(NoEscape(r"\thispagestyle{empty}"))

        doc.append(NoEscape(r"\begin{abstract}\itshape"))
        doc.append(NoEscape(normalize_text(self.abstract.strip())))
        doc.append(NoEscape(r"\end{abstract}"))

        RevisionEntry.render(doc, self.revision_history)

        doc.append(NoEscape(r"\newpage"))
        doc.append(NoEscape(r"\tableofcontents"))
        doc.append(NoEscape(r"\newpage"))

        for cnt in self.content:
            with open(ARTIFACT_DIR / cnt) as f:
                content = DocumentContent.from_dic(**yaml.safe_load(f))
                content.execute(doc)

        return doc
