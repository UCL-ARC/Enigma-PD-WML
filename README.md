# Enigma-PD-WML

Segment White Mater Lesions (WML) in T1-weighted and FLAIR MRI images using FSL and U-Net

## Build and run the docker container

- Clone this repository

```bash
git clone https://github.com/UCL-ARC/Enigma-PD-WML.git
```

- Build the docker image

```bash
cd Enigma-PD-WML
docker build -f Dockerfile -t fsl_test .
```

- Create `code` and `data` directories inside the `Enigma-PD-WML` directory

- Create a `subjects.txt` file at `Enigma-PD-WML/data/subjects.txt`.
  This file should contain subject identifiers (one per line).

- For each subject id:
  - Create a directory at `Enigma-PD-WML/data/subject-id` (replacing 'subject-id' with the relevant id from
    your `subjects.txt` file)

  - Create a sub-directory inside the 'subject-id' directory called `niftis`.

  - Inside `niftis` place the subject's T1 MRI scan and FLAIR MRI scan. Both these files should be in nifti format
    (ending `.nii.gz`) and contain either `T1` or `FLAIR` in their name respectively.

- Your final file structure should look like below (for two example subject ids):

```bash
Enigma-PD-WML
│
├───code
│
└───data
    ├───subject-1
    │   └───niftis
    │       ├───T1.nii.gz
    │       └───FLAIR.nii.gz
    │
    ├───subject-2
    │   └───niftis
    │       ├───T1.nii.gz
    │       └───FLAIR.nii.gz
    └───subjects.txt
```

- Run the docker container. Make sure you are in the `Enigma-PD-WML` directory when you run this command.

```bash
./docker_runscript.sh
```
