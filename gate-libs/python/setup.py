from setuptools import setup, find_packages

setup(
    name="open-gate",
    version="0.1.0",
    packages=find_packages(),
    install_requires=[
        'cffi>=1.15.0',
    ],
    entry_points={
        'console_scripts': [
            'og-pack=open_gate.cli:pack',
            'og-entropy=open_gate.cli:entropy',
            'og-validate=open_gate.cli:validate',
        ],
    },
    author="OPEN GATE Project",
    description="Orthographic-Pack Entropy Gateway",
    license="MIT",
    python_requires=">=3.8",
)
