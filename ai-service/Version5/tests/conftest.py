import sys
from pathlib import Path

# Cho phép import các module của bundle Version5 (labels, paths, ...) trong test
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
