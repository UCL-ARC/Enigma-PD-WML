# Developer docs

## Making new releases to docker hub

This repository has a github actions workflow to automate uploading to
[Docker Hub](https://hub.docker.com/r/hamiedaharoon24/enigma-pd-wml/tags) when a new release is made on github.

- Go to [the releases tab](https://github.com/UCL-ARC/Enigma-PD-WML/releases) and click 'Draft a new release'.

- Click 'Choose a tag' and enter a new version number e.g. `v1.0.0`

- Click 'Generate release notes'. This will add a summary of any commits since the last release.

- Click the green 'Publish release' button at the bottom left.

- This will trigger the action to run and upload the code on the `main` branch to Docker Hub. Note: as the image is very
  large, this will take a while! (around 15 minutes)

## Linting setup (pre-commit)

This repository has another github actions workflow to run various linting checks on pull requests / commits to `main`.
This uses [`pre-commit`](https://pre-commit.com/), a python based tool. The enabled checks can be seen/updated in the
[pre-commit configuration file](https://github.com/UCL-ARC/Enigma-PD-WML/blob/main/.pre-commit-config.yaml).

Some of the main ones used are:

- [hadolint](https://github.com/hadolint/hadolint): for linting Dockerfiles
- [shellcheck](https://www.shellcheck.net/): for linting shell scripts

It can be useful to run `pre-commit` locally to catch issues early. To do so, you will need to have python installed
locally (for example, by installing [Miniforge](https://github.com/conda-forge/miniforge) or similar)

Then run:

```bash
pip install pre-commit
```

Then (from inside a local clone of this github repository), run:

```bash
pre-commit install
```

`pre-commit` should now run automatically every time you `git commit`, flagging any issues.

## Some notes on the Dockerfile

There are two main components to the Dockerfile:

- The requirements for UNets-pgs
- The requirements for FSL

All requirements for the UNets-pgs workflow are coming from the
[base pgs image](https://hub.docker.com/r/cvriend/pgs/tags), including the bash script and packages like tensorflow.

FSL is being installed as detailed in their [installation docs](https://fsl.fmrib.ox.ac.uk/fsl/docs/#/install/container)
and [configuration docs](https://fsl.fmrib.ox.ac.uk/fsl/docs/#/install/configuration). We're using the `-V` option at
the end of the `fslinstaller` command to [fix it to a specific FSL version
](https://fsl.fmrib.ox.ac.uk/fsl/docs/#/install/index?id=installing-older-versions-of-fsl).
