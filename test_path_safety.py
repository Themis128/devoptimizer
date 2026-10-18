import sys
sys.path.insert(0, 'modules')
import importlib.util
spec = importlib.util.spec_from_file_location('config_loader', 'modules/config-loader.py')
config_loader = importlib.util.module_from_spec(spec)
spec.loader.exec_module(config_loader)

# Test cases
test_cases = [
    'configs/system-config.json',
    '../../../etc/passwd',
    '',
    '   ',  # whitespace only
    './configs/system-config.json',
]

for test in test_cases:
    result = config_loader.get_config_path(test)
    is_safe = str(result).startswith('D:\\DevOptimizer\\configs\\')
    print('Input: {!r:20} -> Output: {} (Safe: {})'.format(test, result, is_safe))