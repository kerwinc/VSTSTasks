### Background

This pipeline task provides the ability to create a new branch from the tip of another branch.

## Getting Started

For this extension to work correctly, it's going to need a few super powers to be able to create a new Repo and configure branch policies.
- Enable the "Allow scripts to access the OAuth token" on the pipeline phase
- Give the "Project Collection Build Service" the following permissions on the desired repository
    - Contribute (Allow)
    - Create branch (Allow)
    - Create tag (Allow)
    - Edit policies (Allow)

You can also apply these security changes to the 

### Key Features

- Create a new branch from any repo
- Apply branch basic policy settings to the new branch

### Release Notes

#### 0.0.1

- Initial Preview
