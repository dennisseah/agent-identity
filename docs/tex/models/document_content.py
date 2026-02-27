import yaml
from pydantic import BaseModel
from pylatex import Document, NoEscape

from docs import ARTIFACT_DIR
from docs.tex import normalize_text


class TextContent(BaseModel):
    text: str = ""
    section: str | None = None
    subsection: str | None = None
    subsubsection: str | None = None
    label: str | None = None
    newline: bool = True

    def execute(self, doc: Document) -> None:
        if self.section:
            doc.append(NoEscape(r"\section{" + normalize_text(self.section) + "}"))
        if self.subsection:
            doc.append(
                NoEscape(r"\subsection{" + normalize_text(self.subsection) + "}")
            )
        if self.subsubsection:
            doc.append(
                NoEscape(r"\subsubsection{" + normalize_text(self.subsubsection) + "}")
            )
        if self.label:
            doc.append(NoEscape(r"\label{" + self.label + "}"))
        doc.append(NoEscape(normalize_text(self.text)))
        if self.newline:
            doc.append(NoEscape(r"\par\vspace{\baselineskip}"))


class VerbatimContent(BaseModel):
    text: str
    newline: bool = True
    font_size: str = "small"

    def execute(self, doc: Document) -> None:
        verbatim_block = (
            "{\\" + self.font_size + "\n"
            r"\begin{verbatim}" + "\n" + self.text + "\n" + r"\end{verbatim}}"
        )
        doc.append(NoEscape(verbatim_block))
        if self.newline:
            doc.append(NoEscape(r"\vspace{\baselineskip}"))


class ItemizeContent(BaseModel):
    items: list[str | dict]
    newline: bool = True

    def execute(self, doc: Document) -> None:
        doc.append(NoEscape(r"\begin{itemize}[topsep=0pt]"))
        for item in self.items:
            if isinstance(item, dict):
                parts = item.get("parts", [])
                font_size = item.get("font_size", "small")
                if parts:
                    first = True
                    for part in parts:
                        if "text" in part:
                            prefix = r"\item " if first else ""
                            doc.append(NoEscape(prefix + normalize_text(part["text"])))
                            first = False
                        elif "code" in part:
                            doc.append(
                                NoEscape(
                                    "\\begin{Verbatim}[fontsize=\\"
                                    + font_size
                                    + "]\n"
                                    + part["code"].rstrip()
                                    + "\n"
                                    + "\\end{Verbatim}\n"
                                )
                            )
                            first = False
                else:
                    # Legacy format: text/code keys at top level
                    text = item.get("text", "")
                    code = item.get("code", "")
                    doc.append(NoEscape(r"\item " + normalize_text(text)))
                    if code:
                        doc.append(
                            NoEscape(
                                "\\begin{Verbatim}[fontsize=\\"
                                + font_size
                                + "]\n"
                                + code.rstrip()
                                + "\n"
                                + "\\end{Verbatim}\n"
                            )
                        )
            else:
                doc.append(NoEscape(r"\item " + normalize_text(item)))
        doc.append(NoEscape(r"\end{itemize}"))
        if self.newline:
            doc.append(NoEscape(r"\vspace{\baselineskip}"))


class ImageContent(BaseModel):
    src: str
    caption: str
    label: str | None = None
    width: str = "0.8\\textwidth"
    placement: str = "htbp"  # h=here, t=top, b=bottom, p=page; use "H" for exact

    def execute(self, doc: Document) -> None:
        doc.append(NoEscape(r"\begin{figure}[" + self.placement + "]"))
        doc.append(
            NoEscape(
                r"\centering" + f"\n\\includegraphics[width={self.width}]{{{self.src}}}"
            )
        )
        doc.append(NoEscape(r"\caption{" + normalize_text(self.caption) + "}"))
        if self.label:
            doc.append(NoEscape(r"\label{" + self.label + "}"))
        doc.append(NoEscape(r"\end{figure}"))
        doc.append(NoEscape(r"\vspace{\baselineskip}"))


class EmbededContent(BaseModel):
    src: str

    def execute(self, doc: Document) -> None:
        with open(ARTIFACT_DIR / self.src) as f:
            raw = yaml.safe_load(f)
            DocumentContent.from_dic(**raw).execute(doc)


class DocumentContent(BaseModel):
    title: str | None = None
    label: str | None = None
    content: list[
        TextContent | ItemizeContent | ImageContent | VerbatimContent | EmbededContent
    ] = []

    def execute(self, doc: Document) -> None:
        if self.title:
            doc.append(NoEscape(r"\section{" + normalize_text(self.title) + "}"))
        if self.label:
            doc.append(NoEscape(r"\label{" + self.label + "}"))
        for cnt in self.content:
            cnt.execute(doc)

    @classmethod
    def from_dic(cls, **data) -> "DocumentContent":
        content = data.get("content", [])
        del data["content"]
        doc = cls(**data)

        for c in content:
            type = c.pop("type")
            if type == "embed":
                doc.content.append(EmbededContent(**c))
            elif type == "paragraph":
                doc.content.append(TextContent(**c))
            elif type == "itemize":
                doc.content.append(ItemizeContent(**c))
            elif type == "image":
                doc.content.append(ImageContent(**c))
            elif type == "code":
                doc.content.append(VerbatimContent(**c))
        return doc
