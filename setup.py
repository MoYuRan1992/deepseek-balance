from setuptools import setup

APP = ['deepseek_balance_app.py']
DATA_FILES = []
OPTIONS = {
    'argv_emulation': False,
    'plist': {
        'LSUIElement': True,
        'CFBundleName': 'DeepSeek Balance',
        'CFBundleIdentifier': 'com.deepseek.balance',
        'CFBundleVersion': '1.0',
        'CFBundleShortVersionString': '1.0',
        'LSMinimumSystemVersion': '10.14',
    },
    'iconfile': 'AppIcon.icns',
    'packages': ['rumps', 'certifi'],
    'includes': ['AppKit', 'Foundation'],
}

setup(
    app=APP,
    data_files=DATA_FILES,
    options={'py2app': OPTIONS},
    setup_requires=['py2app'],
)
