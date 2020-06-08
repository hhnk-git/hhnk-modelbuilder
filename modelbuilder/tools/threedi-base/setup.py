import os

from setuptools import setup, find_packages

project_dir = os.path.abspath(os.path.dirname(__file__))
README = open(os.path.join(project_dir, 'README.rst')).read()
CHANGES = open(os.path.join(project_dir, 'CHANGES.rst')).read()
version = open(os.path.join(project_dir, 'version.txt')).readlines()[0]
requirements = open(os.path.join(project_dir, 'requirements.txt')).readlines()

long_description = '\n\n'.join([README, CHANGES])

requires = open(os.path.join(project_dir, 'requirements.txt')).readlines()

setup(name='threedi-base',
      version=version,
      description='tools to help Nelen en Schuurmans modelers to '
                  'build a base schema for a 3Di model',
      long_description=long_description,
      classifiers=[
          "Programming Language :: Python",
          "Topic :: GEO"],
      author="Lars Claussen",
      author_email="lars.claussen@nelen-schuurmans.nl",
      url="http://nelen-schuurmans.nl",
      keywords="3Di",
      packages=find_packages(),
      include_package_data=True,
      zip_safe=False,
      install_require=requires,
      test_require=requires,
      test_suite="")
