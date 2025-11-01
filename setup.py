from setuptools import setup, find_packages

with open("README.md", "r", encoding="utf-8") as fh:
    long_description = fh.read()

setup(
    name="whisper_transcription_tool",
    version="0.9.6",
    author="Whisper Transcription Tool Team",
    author_email="example@example.com",
    description="A modular Python tool for audio transcription using Whisper.cpp on Apple Silicon",
    long_description=long_description,
    long_description_content_type="text/markdown",
    url="https://github.com/yourusername/whisper_transcription_tool",
    packages=find_packages(where="src"),
    package_dir={"":"src"},
    classifiers=[
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.11",
        "Programming Language :: Python :: 3.13",
        "License :: OSI Approved :: MIT License",
        "Operating System :: MacOS :: MacOS X",
        "Topic :: Multimedia :: Sound/Audio :: Speech",
        "Topic :: Scientific/Engineering :: Artificial Intelligence",
    ],
    python_requires=">=3.11",
    install_requires=[
        "numpy",
        "httpx", # For making HTTP requests, especially for model downloads
        "tqdm",
        "pyyaml",
        "fastapi",
        "uvicorn",
        "jinja2",
        "python-multipart",
        "srt",
        "websockets",
    ],
    extras_require={
        "llm": ["llama-cpp-python>=0.2.0", "sentencepiece>=0.1.99", "nltk>=3.8", "transformers>=4.21.0", "packaging>=20.0"],
        "web": ["fastapi", "uvicorn", "jinja2", "python-multipart", "websockets", "httpx"],
        "dev": ["pytest", "black", "isort", "flake8", "mypy"],
        "full": ["fastapi", "uvicorn", "jinja2", "python-multipart", "srt", "websockets", "httpx", "llama-cpp-python>=0.2.0", "sentencepiece>=0.1.99", "nltk>=3.8", "transformers>=4.21.0", "packaging>=20.0"]
    },
    entry_points={
        "console_scripts": [
            "whisper-tool=whisper_transcription_tool.main:main",
        ],
    },
    include_package_data=True,
    package_data={
        'whisper_transcription_tool': [
            'web/static/css/*.css',
            'web/static/js/*.js',
            'web/templates/*.html',
        ],
    },
)
