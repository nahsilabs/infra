import json
from pathlib import Path
import shutil
import subprocess
import tomllib

import tomli_w
from pm.plugin_declarations import read_python_declaration

root = Path('/opt/hermes')
plugin_paths = [
    root / 'plugins/memory/hindsight',
    root / 'plugins/langfuse',
    root / 'plugins/context_engine/hermes-snapcompact',
]
requirements = {
    requirement
    for path in plugin_paths
    for requirement in read_python_declaration(path).install_requirements
}
requirements.update((root / 'requirements.txt').read_text().splitlines())
project_path = root / 'pyproject.toml'
project = tomllib.loads(project_path.read_text())
project['project']['optional-dependencies']['image-plugins'] = sorted(requirements)
project_path.write_text(tomli_w.dumps(project))

facts_path = root / 'tools/facts.json'
extras = set(json.loads(facts_path.read_text())['packages']['venv']['extras'])
extras.add('image-plugins')
shutil.rmtree(root / '.venv')
subprocess.run([
    '/usr/local/bin/python3', '-m', 'pm.build_env',
    '--source', str(root), '--python', '/usr/local/bin/python3',
    '--out', str(root / '.venv'), '--cache', '/tmp/hermes-build-cache',
    '--resolve', '--no-install-project', '--sealed', '--record-selection',
    *[argument for extra in sorted(extras) for argument in ('--extra', extra)],
], check=True)
subprocess.run([str(root / '.venv/bin/python'), '-m', 'docker.build_agent'], check=True)
facts_path.chmod(0o644)
(root / '.venv/.lock').unlink(missing_ok=True)
