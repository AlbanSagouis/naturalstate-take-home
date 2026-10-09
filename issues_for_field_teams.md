Herbaceous vegetation survey: errors and warnings for the field teams
================
Alban Sagouis
2026-10-08

## TL;DR

- This list has 106 items in 28 of the 30 accepted submissions (28
  plots): 10 errors and 96 warnings. Nothing was changed or removed in
  the data.
- 2 submissions were rejected in ODK and are not on this list; their 8
  errors and warnings stay in `outputs/vegetation/flags.csv`.
- Errors break a rule of the survey protocol (SOP) or contradict other
  answers. Warnings need a look and may be fine.
- 61 items can be resolved by the field team, 23 by the data manager and
  22 by the Tech team (they come from the form, not from the field).
- The most common field problems: quadrat locations far from the plot
  midpoint (33 quadrats), extra species announced but not recorded (9
  quadrats), and probable misspellings (3 names). Species names typed
  with a space instead of an underscore are not on the list: the form
  accepts a space, so it is a form issue for Tech.
- 849 further notes (for example species still to be identified) are in
  `outputs/vegetation/flags.csv` and are not repeated here.

## How to read this list

Each plot has one section and each submission (one visit) one
sub-section. Quadrat numbers are the numbers in the form. “Check” lines
say what to look at. Section numbers refer to the Herbaceous Vegetation
Surveys SOP and the Vegetation Plot Registration SOP (version 2026.1).
The full list as a table is
`outputs/vegetation/issues_for_field_teams.csv`; the rules behind each
item are in `outputs/vegetation/check_catalogue.csv`.

## SavMon_LW_Plot_01

### 2026-05-23, recorded by Grace_Achieng (6 items)

- Warning: The end summary says 19 quadrats had species; the data
  show 20. (Tech)
- Warning: Quadrat 9 is 35.9 m from the plot midpoint; the belt allows
  34.1 m. (field team)
- Warning: Quadrat 18 is 74.6 m from the plot midpoint; the belt allows
  34.4 m. (field team)
- Warning: Quadrat 6 has exactly the same location as another quadrat of
  this survey. (field team)
- Warning: Quadrat 14 has exactly the same location as another quadrat
  of this survey. (field team)
- Warning: The reused name “Evolvulus alsinoides” has a space at the
  start or end. (data manager)

Check:

- Form issue: the summary counts only quadrats with extra species. Fix
  the form calculation so step 13 of the SOP can rely on it.
- Check the quadrat location and the plot midpoint.
- Wait for a new fix at each quadrat.
- Fix the label once in the extra-species list.

SOP: Herbaceous SOP section 5 step 13; Herbaceous SOP section 2 (Belt
transect) and Registration SOP section 3; Herbaceous SOP section 5 step
9; Herbaceous SOP section 5 step 7

## SavMon_LW_Plot_02

### 2026-05-24, recorded by Grace_Achieng (4 items)

- Warning: The end summary says 17 quadrats had species; the data
  show 19. (Tech)
- Warning: Quadrat 10 is 35.8 m from the plot midpoint; the belt allows
  32.6 m. (field team)
- Warning: Quadrat 2: “Brachiara dura” looks like a misspelling of
  “Brachiaria”. (field team)
- Warning: The reused name “Evolvulus alsinoides” has a space at the
  start or end. (data manager)

Check:

- Form issue: the summary counts only quadrats with extra species. Fix
  the form calculation so step 13 of the SOP can rely on it.
- Check the quadrat location and the plot midpoint.
- Check the spelling and select the species from the list if it is the
  same.
- Fix the label once in the extra-species list.

SOP: Herbaceous SOP section 5 step 13; Herbaceous SOP section 2 (Belt
transect) and Registration SOP section 3; Herbaceous SOP section 4.2 and
section 5 step 7; Herbaceous SOP section 5 step 7

## SavMon_LW_Plot_03

### 2026-05-20, recorded by Samuel_Kiprotich (2 items)

- Warning: Quadrat 1 is 40 m from the plot midpoint; the belt allows
  33.1 m. (field team)
- Warning: Quadrat 6: Aristida scabrivalvis was entered as a new species
  more than once. (data manager)

Check:

- Check the quadrat location and the plot midpoint.
- Merge the duplicate new-species entries.

SOP: Herbaceous SOP section 2 (Belt transect) and Registration SOP
section 3; Herbaceous SOP section 4.2 and section 6

## SavMon_LW_Plot_04

### 2026-05-25, recorded by Grace_Achieng (3 items)

- Warning: The end summary says 18 quadrats had species; the data
  show 19. (Tech)
- Warning: Quadrat 1 is 39.8 m from the plot midpoint; the belt allows
  30.2 m. (field team)
- Warning: Quadrat 3 is 33 m from the plot midpoint; the belt allows
  31.1 m. (field team)

Check:

- Form issue: the summary counts only quadrats with extra species. Fix
  the form calculation so step 13 of the SOP can rely on it.
- Check the quadrat location and the plot midpoint.

SOP: Herbaceous SOP section 5 step 13; Herbaceous SOP section 2 (Belt
transect) and Registration SOP section 3

## SavMon_LW_Plot_05

### 2026-05-22, recorded by Grace_Achieng (9 items)

- Warning: The end summary says 12 quadrats had species; the data
  show 19. (Tech)
- Warning: Quadrat 1 is 42.4 m from the plot midpoint; the belt allows
  32.3 m. (field team)
- Warning: Quadrat 2 is 42.1 m from the plot midpoint; the belt allows
  32.2 m. (field team)
- Warning: Quadrat 3 is 38.3 m from the plot midpoint; the belt allows
  32 m. (field team)
- Warning: Quadrat 4 is 37.3 m from the plot midpoint; the belt allows
  32.4 m. (field team)
- Warning: Quadrat 19 is 34.3 m from the plot midpoint; the belt allows
  33.9 m. (field team)
- Warning: Quadrat 20 is 43.5 m from the plot midpoint; the belt allows
  33.1 m. (field team)
- Warning: The end-of-survey location is 43.5 m from the plot midpoint;
  the plot allows 33.1 m. (field team)
- Warning: Quadrat 9: “Ipomea sinensis” looks like a misspelling of
  “Ipomoea”. (field team)

Check:

- Form issue: the summary counts only quadrats with extra species. Fix
  the form calculation so step 13 of the SOP can rely on it.
- Check the quadrat location and the plot midpoint.
- Check that the survey was done at the registered plot.
- Check the spelling and select the species from the list if it is the
  same.

SOP: Herbaceous SOP section 5 step 13; Herbaceous SOP section 2 (Belt
transect) and Registration SOP section 3; Herbaceous SOP section 2 (Belt
transect); Herbaceous SOP section 4.2 and section 5 step 7

## SavMon_LW_Plot_06

### 2026-05-23, recorded by Grace_Achieng (1 item)

- Warning: Quadrat 1 is 34.5 m from the plot midpoint; the belt allows
  31.4 m. (field team)

Check:

- Check the quadrat location and the plot midpoint.

SOP: Herbaceous SOP section 2 (Belt transect) and Registration SOP
section 3

## SavMon_LW_Plot_07

### 2026-05-24, recorded by Grace_Achieng (1 item)

- Warning: The end summary says 17 quadrats had species; the data
  show 20. (Tech)

Check:

- Form issue: the summary counts only quadrats with extra species. Fix
  the form calculation so step 13 of the SOP can rely on it.

SOP: Herbaceous SOP section 5 step 13

## SavMon_LW_Plot_08

### 2026-05-19, recorded by Samuel_Kiprotich (3 items)

- Warning: The end summary says 19 quadrats had species; the data
  show 20. (Tech)
- Warning: Quadrat 1: the name “Evolvulus alsinoides” has a space at the
  start or end. (field team)
- Warning: The survey took 236 minutes, outside the expected 15 to 180.
  (field team)

Check:

- Form issue: the summary counts only quadrats with extra species. Fix
  the form calculation so step 13 of the SOP can rely on it.
- Remove the space.
- Check that the whole plot was surveyed and the form was not left open.

SOP: Herbaceous SOP section 5 step 13; Herbaceous SOP section 5 step 7;
Herbaceous SOP section 5 (20 quadrats with photos)

## SavMon_LW_Plot_09

### 2026-05-21, recorded by Grace_Achieng (4 items)

- Warning: The end summary says 19 quadrats had species; the data
  show 20. (Tech)
- Warning: Quadrat 10 is 39.6 m from the plot midpoint; the belt allows
  31.8 m. (field team)
- Warning: Quadrat 9: Justicia divaricata was entered as a new species
  more than once. (data manager)
- Warning: The reused name “Evolvulus alsinoides” has a space at the
  start or end. (data manager)

Check:

- Form issue: the summary counts only quadrats with extra species. Fix
  the form calculation so step 13 of the SOP can rely on it.
- Check the quadrat location and the plot midpoint.
- Merge the duplicate new-species entries.
- Fix the label once in the extra-species list.

SOP: Herbaceous SOP section 5 step 13; Herbaceous SOP section 2 (Belt
transect) and Registration SOP section 3; Herbaceous SOP section 4.2 and
section 6; Herbaceous SOP section 5 step 7

## SavMon_LW_Plot_10

### 2026-05-21, recorded by Grace_Achieng (2 items)

- Error: Quadrat 9 says extra species were found but none is recorded.
  (field team)
- Warning: The end summary says 18 quadrats had species; the data
  show 20. (Tech)

Check:

- Look up the extra species on the field sheet and send them to the data
  manager.
- Form issue: the summary counts only quadrats with extra species. Fix
  the form calculation so step 13 of the SOP can rely on it.

SOP: Herbaceous SOP section 5 step 7; Herbaceous SOP section 5 step 13

## SavMon_LW_Plot_11

### 2026-05-26, recorded by Grace_Achieng (3 items)

- Warning: Quadrat 2: herb_054 is listed more than once. (field team)
- Warning: Quadrat 4 is 50.8 m from the plot midpoint; the belt allows
  33 m. (field team)
- Warning: The reused name “Evolvulus alsinoides” has a space at the
  start or end. (data manager)

Check:

- Remove the duplicate if it is the same plant.
- Check the quadrat location and the plot midpoint.
- Fix the label once in the extra-species list.

SOP: Herbaceous SOP section 3 (presence recorded per quadrat);
Herbaceous SOP section 2 (Belt transect) and Registration SOP section 3;
Herbaceous SOP section 5 step 7

## SavMon_LW_Plot_12

### 2026-05-20, recorded by Samuel_Kiprotich (4 items)

- Warning: Quadrat 2: herb_010 is listed more than once. (field team)
- Warning: Quadrat 4: herb_017 is listed more than once. (field team)
- Warning: Quadrat 20: herb_016 is listed more than once. (field team)
- Warning: The reused name “Evolvulus alsinoides” has a space at the
  start or end. (data manager)

Check:

- Remove the duplicate if it is the same plant.
- Fix the label once in the extra-species list.

SOP: Herbaceous SOP section 3 (presence recorded per quadrat);
Herbaceous SOP section 5 step 7

## SavMon_LW_Plot_14

### 2026-05-21, recorded by Grace_Achieng (5 items)

- Error: Quadrat 8 says extra species were found but none is recorded.
  (field team)
- Warning: The end summary says 11 quadrats had species; the data
  show 20. (Tech)
- Warning: Quadrat 10 is 32.2 m from the plot midpoint; the belt allows
  31.3 m. (field team)
- Warning: Quadrat 7: Pechuel-loeschea leubnitziae is already on the
  species list and should have been selected. (data manager)
- Warning: The reused name “Evolvulus alsinoides” has a space at the
  start or end. (data manager)

Check:

- Look up the extra species on the field sheet and send them to the data
  manager.
- Form issue: the summary counts only quadrats with extra species. Fix
  the form calculation so step 13 of the SOP can rely on it.
- Check the quadrat location and the plot midpoint.
- Replace the typed entry with the list species.
- Fix the label once in the extra-species list.

SOP: Herbaceous SOP section 5 step 7; Herbaceous SOP section 5 step 13;
Herbaceous SOP section 2 (Belt transect) and Registration SOP section 3;
Herbaceous SOP section 4.2 and section 5 step 7

## SavMon_LW_Plot_15

### 2026-05-24, recorded by Grace_Achieng (5 items)

- Error: Quadrat 17 says extra species were found but none is recorded.
  (field team)
- Warning: The end summary says 17 quadrats had species; the data
  show 20. (Tech)
- Warning: Quadrat 10 is 33.6 m from the plot midpoint; the belt allows
  31.7 m. (field team)
- Warning: Quadrat 11 is 34.2 m from the plot midpoint; the belt allows
  32 m. (field team)
- Warning: Quadrat 3: “Ipomea leucanthemum” looks like a misspelling of
  “Ipomoea”. (field team)

Check:

- Look up the extra species on the field sheet and send them to the data
  manager.
- Form issue: the summary counts only quadrats with extra species. Fix
  the form calculation so step 13 of the SOP can rely on it.
- Check the quadrat location and the plot midpoint.
- Check the spelling and select the species from the list if it is the
  same.

SOP: Herbaceous SOP section 5 step 7; Herbaceous SOP section 5 step 13;
Herbaceous SOP section 2 (Belt transect) and Registration SOP section 3;
Herbaceous SOP section 4.2 and section 5 step 7

## SavMon_LW_Plot_16

### 2026-05-27, recorded by Grace_Achieng (4 items)

- Warning: The end summary says 19 quadrats had species; the data
  show 20. (Tech)
- Warning: Quadrat 16: the name “Justicia divaricata” has a space at the
  start or end. (field team)
- Warning: Quadrat 16: Justicia divaricata was entered as a new species
  more than once. (data manager)
- Warning: The reused name “Evolvulus alsinoides” has a space at the
  start or end. (data manager)

Check:

- Form issue: the summary counts only quadrats with extra species. Fix
  the form calculation so step 13 of the SOP can rely on it.
- Remove the space.
- Merge the duplicate new-species entries.
- Fix the label once in the extra-species list.

SOP: Herbaceous SOP section 5 step 13; Herbaceous SOP section 5 step 7;
Herbaceous SOP section 4.2 and section 6

## SavMon_LW_Plot_18

### 2026-05-26, recorded by Grace_Achieng (3 items)

- Warning: Quadrat 2: Oldenladia corymbosa is listed more than once.
  (field team)
- Warning: Quadrat 20 is 31.1 m from the plot midpoint; the belt allows
  30.8 m. (field team)
- Warning: The reused name “Evolvulus alsinoides” has a space at the
  start or end. (data manager)

Check:

- Remove the duplicate if it is the same plant.
- Check the quadrat location and the plot midpoint.
- Fix the label once in the extra-species list.

SOP: Herbaceous SOP section 3 (presence recorded per quadrat);
Herbaceous SOP section 2 (Belt transect) and Registration SOP section 3;
Herbaceous SOP section 5 step 7

## SavMon_LW_Plot_19

### 2026-05-22, recorded by Grace_Achieng (4 items)

- Error: Quadrat 20 says extra species were found but none is recorded.
  (field team)
- Warning: The end summary says 16 quadrats had species; the data
  show 19. (Tech)
- Warning: Quadrat 3 is 47.3 m from the plot midpoint; the belt allows
  31.7 m. (field team)
- Warning: The reused name “Evolvulus alsinoides” has a space at the
  start or end. (data manager)

Check:

- Look up the extra species on the field sheet and send them to the data
  manager.
- Form issue: the summary counts only quadrats with extra species. Fix
  the form calculation so step 13 of the SOP can rely on it.
- Check the quadrat location and the plot midpoint.
- Fix the label once in the extra-species list.

SOP: Herbaceous SOP section 5 step 7; Herbaceous SOP section 5 step 13;
Herbaceous SOP section 2 (Belt transect) and Registration SOP section 3

## SavMon_LW_Plot_20

### 2026-05-24, recorded by Grace_Achieng (2 items)

- Warning: The end summary says 19 quadrats had species; the data
  show 20. (Tech)
- Warning: The reused name “Evolvulus alsinoides” has a space at the
  start or end. (data manager)

Check:

- Form issue: the summary counts only quadrats with extra species. Fix
  the form calculation so step 13 of the SOP can rely on it.
- Fix the label once in the extra-species list.

SOP: Herbaceous SOP section 5 step 13; Herbaceous SOP section 5 step 7

## SavMon_LW_Plot_21

### 2026-05-26, recorded by Grace_Achieng (4 items)

- Warning: The end summary says 19 quadrats had species; the data
  show 20. (Tech)
- Warning: Quadrat 10 is 38.7 m from the plot midpoint; the belt allows
  32.5 m. (field team)
- Warning: Quadrat 13: Cyperus margaritaceus was entered as a new
  species more than once. (data manager)
- Warning: The reused name “Evolvulus alsinoides” has a space at the
  start or end. (data manager)

Check:

- Form issue: the summary counts only quadrats with extra species. Fix
  the form calculation so step 13 of the SOP can rely on it.
- Check the quadrat location and the plot midpoint.
- Merge the duplicate new-species entries.
- Fix the label once in the extra-species list.

SOP: Herbaceous SOP section 5 step 13; Herbaceous SOP section 2 (Belt
transect) and Registration SOP section 3; Herbaceous SOP section 4.2 and
section 6; Herbaceous SOP section 5 step 7

## SavMon_LW_Plot_22

### 2026-05-20, recorded by Samuel_Kiprotich (7 items)

- Warning: The end summary says 16 quadrats had species; the data
  show 20. (Tech)
- Warning: Quadrat 14: Macrotalyma daltonii is listed more than once.
  (field team)
- Warning: Quadrat 8 is 37.9 m from the plot midpoint; the belt allows
  34.4 m. (field team)
- Warning: Quadrat 11 is 45.9 m from the plot midpoint; the belt allows
  32.7 m. (field team)
- Warning: Quadrat 12 is 33.7 m from the plot midpoint; the belt allows
  33.1 m. (field team)
- Warning: Quadrat 14 is 33.3 m from the plot midpoint; the belt allows
  33.2 m. (field team)
- Warning: The reused name “Evolvulus alsinoides” has a space at the
  start or end. (data manager)

Check:

- Form issue: the summary counts only quadrats with extra species. Fix
  the form calculation so step 13 of the SOP can rely on it.
- Remove the duplicate if it is the same plant.
- Check the quadrat location and the plot midpoint.
- Fix the label once in the extra-species list.

SOP: Herbaceous SOP section 5 step 13; Herbaceous SOP section 3
(presence recorded per quadrat); Herbaceous SOP section 2 (Belt
transect) and Registration SOP section 3; Herbaceous SOP section 5 step
7

## SavMon_LW_Plot_24

### 2026-05-24, recorded by Grace_Achieng (2 items)

- Warning: The end summary says 19 quadrats had species; the data
  show 20. (Tech)
- Warning: Quadrat 1 is 31.1 m from the plot midpoint; the belt allows
  30.5 m. (field team)

Check:

- Form issue: the summary counts only quadrats with extra species. Fix
  the form calculation so step 13 of the SOP can rely on it.
- Check the quadrat location and the plot midpoint.

SOP: Herbaceous SOP section 5 step 13; Herbaceous SOP section 2 (Belt
transect) and Registration SOP section 3

## SavMon_LW_Plot_25

### 2026-05-25, recorded by Grace_Achieng (4 items)

- Warning: The end summary says 19 quadrats had species; the data
  show 20. (Tech)
- Warning: Quadrat 1 is 38 m from the plot midpoint; the belt allows
  31.6 m. (field team)
- Warning: The end-of-survey location is 30.6 m from the plot midpoint;
  the plot allows 29.7 m. (field team)
- Warning: The reused name “Evolvulus alsinoides” has a space at the
  start or end. (data manager)

Check:

- Form issue: the summary counts only quadrats with extra species. Fix
  the form calculation so step 13 of the SOP can rely on it.
- Check the quadrat location and the plot midpoint.
- Check that the survey was done at the registered plot.
- Fix the label once in the extra-species list.

SOP: Herbaceous SOP section 5 step 13; Herbaceous SOP section 2 (Belt
transect) and Registration SOP section 3; Herbaceous SOP section 2 (Belt
transect); Herbaceous SOP section 5 step 7

## SavMon_LW_Plot_26

### 2026-05-22, recorded by Grace_Achieng (4 items)

- Warning: The end summary says 19 quadrats had species; the data
  show 20. (Tech)
- Warning: Quadrat 11 is 34.4 m from the plot midpoint; the belt allows
  33.2 m. (field team)
- Warning: Quadrat 20 is 32.7 m from the plot midpoint; the belt allows
  32 m. (field team)
- Warning: Quadrat 1: Aristida scabrivalvis was entered as a new species
  more than once. (data manager)

Check:

- Form issue: the summary counts only quadrats with extra species. Fix
  the form calculation so step 13 of the SOP can rely on it.
- Check the quadrat location and the plot midpoint.
- Merge the duplicate new-species entries.

SOP: Herbaceous SOP section 5 step 13; Herbaceous SOP section 2 (Belt
transect) and Registration SOP section 3; Herbaceous SOP section 4.2 and
section 6

## SavMon_LW_Plot_27

### 2026-05-22, recorded by Grace_Achieng (2 items)

- Warning: The end summary says 19 quadrats had species; the data
  show 20. (Tech)
- Warning: The reused name “Evolvulus alsinoides” has a space at the
  start or end. (data manager)

Check:

- Form issue: the summary counts only quadrats with extra species. Fix
  the form calculation so step 13 of the SOP can rely on it.
- Fix the label once in the extra-species list.

SOP: Herbaceous SOP section 5 step 13; Herbaceous SOP section 5 step 7

## SavMon_LW_Plot_28

### 2026-05-23, recorded by Grace_Achieng (2 items)

- Error: Quadrat 6: an extra species has no name. (field team)
- Warning: The reused name “Evolvulus alsinoides” has a space at the
  start or end. (data manager)

Check:

- Look up the species on the field sheet.
- Fix the label once in the extra-species list.

SOP: Herbaceous SOP section 5 step 7

## SavMon_LW_Plot_29

### 2026-05-26, recorded by Samuel_Kiprotich (3 items)

- Error: Quadrat 2 says extra species were found but none is recorded.
  (field team)
- Warning: The end summary says 19 quadrats had species; the data
  show 20. (Tech)
- Warning: The reused name “Evolvulus alsinoides” has a space at the
  start or end. (data manager)

Check:

- Look up the extra species on the field sheet and send them to the data
  manager.
- Form issue: the summary counts only quadrats with extra species. Fix
  the form calculation so step 13 of the SOP can rely on it.
- Fix the label once in the extra-species list.

SOP: Herbaceous SOP section 5 step 7; Herbaceous SOP section 5 step 13

## SavMon_LW_Plot_30

### 2026-05-21, recorded by Grace_Achieng (9 items)

- Error: Quadrat 14 says extra species were found but none is recorded.
  (field team)
- Warning: The end summary says 14 quadrats had species; the data
  show 20. (Tech)
- Warning: The end-of-survey location accuracy is 5.066 m, above 5 m.
  (field team)
- Warning: Quadrat 1 is 43.4 m from the plot midpoint; the belt allows
  33.2 m. (field team)
- Warning: Quadrat 2 is 37 m from the plot midpoint; the belt allows
  32.2 m. (field team)
- Warning: Quadrat 3 is 32.4 m from the plot midpoint; the belt allows
  31.9 m. (field team)
- Warning: Quadrat 20 is 36.7 m from the plot midpoint; the belt allows
  34.6 m. (field team)
- Warning: The end-of-survey location is 43.4 m from the plot midpoint;
  the plot allows 34.7 m. (field team)
- Warning: The reused name “Evolvulus alsinoides” has a space at the
  start or end. (data manager)

Check:

- Look up the extra species on the field sheet and send them to the data
  manager.
- Form issue: the summary counts only quadrats with extra species. Fix
  the form calculation so step 13 of the SOP can rely on it.
- Set the device to 5 m accuracy or better.
- Check the quadrat location and the plot midpoint.
- Check that the survey was done at the registered plot.
- Fix the label once in the extra-species list.

SOP: Herbaceous SOP section 5 step 7; Herbaceous SOP section 5 step 13;
Herbaceous SOP section 4.2; Herbaceous SOP section 2 (Belt transect) and
Registration SOP section 3; Herbaceous SOP section 2 (Belt transect)

## SavMon_LW_Plot_46

### 2026-05-22, recorded by Grace_Achieng (4 items)

- Error: Quadrat 5 says extra species were found but none is recorded.
  (field team)
- Error: Quadrat 13 says extra species were found but none is recorded.
  (field team)
- Error: Quadrat 14 says extra species were found but none is recorded.
  (field team)
- Warning: The end summary says 14 quadrats had species; the data
  show 20. (Tech)

Check:

- Look up the extra species on the field sheet and send them to the data
  manager.
- Form issue: the summary counts only quadrats with extra species. Fix
  the form calculation so step 13 of the SOP can rely on it.

SOP: Herbaceous SOP section 5 step 7; Herbaceous SOP section 5 step 13
