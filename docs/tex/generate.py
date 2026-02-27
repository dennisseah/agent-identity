import os
import pathlib

import yaml

from docs.tex.models.document_config import DocumentConfig

CURRENT_DIR = pathlib.Path(os.path.dirname(__file__)) / "artifacts"
PROJECT_ROOT = pathlib.Path(os.path.dirname(__file__)).parent.parent


def main():
    with open(CURRENT_DIR / "doc.yaml") as f:
        cfg = DocumentConfig(**yaml.safe_load(f))
        doc = cfg.execute()

    # Clean latexmk state file to prevent "gave an error in previous invocation"
    fdb = PROJECT_ROOT / f"{cfg.output_file}.fdb_latexmk"
    if fdb.exists():
        os.remove(fdb)

    doc.generate_pdf(cfg.output_file, clean_tex=False)


if __name__ == "__main__":
    main()
