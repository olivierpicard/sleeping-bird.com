import json
from pathlib import Path

from app.main import app

OUTPUT = Path(__file__).resolve().parent.parent / "openapi.json"


def main() -> None:
    OUTPUT.write_text(json.dumps(app.openapi(), indent=2))
    print(f"{OUTPUT.name} generated.")


if __name__ == "__main__":
    main()
