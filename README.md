# empathy_study_public
Task code and analysis code for study on empathy. Pairs of subjects (one 'participant' and their 'companion') completed the task together. On each trial, one of them received an electric shock at one of three levels: high (painful), low (non-painful), or safe (no shock). Both participants then rated their emotional responses on a tablet. Electrocardiogram, electrodermal activity, and respiration were recorded continuously for both subjects. Beat-to-beat blood pressure was recorded continuously for one subject. Both subjects also underwent a two-minute resting state recording of these physiological measures. Both subjects completed a battery of self-report pscyhometric questionnaires measuring ADHD traits and emotion traits (e.g. emotion regulation, empathy).

Primary and secondary analyses were pre-registered at https://osf.io/r8f7j

PLEASE NOTE: as of February 2026, participant datafiles cannot be publicised in the repository due to journal restrictions. They will be uploaded once the manuscript is published.

-------Key to files-------
- empathy_task.m     MATLAB task script, which displays trial information to each subject via a separate monitor and delivers shocks to either subject's ankle via the parallel port and two Digitimer DS 7 devices
- .jpg files     Stimuli for empathy_task.m
- submit_ratings_on_tablets.html     html/JavaScript/CSS script for each subject to rate their emotions, run on one Android tablets for each subject
- Empathy task data preprocessing.ipynb     Jupyter notebook (python) script for linking psychophysiology data to task conditions datafile, checking psychophysiology data, and calculating psychophysiology metrics
- empathyAnalysis.rmd     R markdown script for statistical analysis of task data
