## Release Notes

A non-exhaustive list of what has changed in a more readable form than a commit history.

### v1.0.1

  - Standard measure calculations are now requirements of the custom measure injection, since our current custom measures use/overwrite the standard measure calculations

### v1.0.0

  - Initial release of product component
    - Set up python library for promotion, reference data creation, and Luigi pipeline
    - Moved measure calculation scripts and related reference data into this component
    - Updated measure calculation scripts to work with compiled reference data
    - Moved unit test scripts into this component
    - Set up CI framework
