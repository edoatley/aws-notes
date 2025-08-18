SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "${SCRIPT_DIR}"

python3.12 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
pip install --upgrade pip
