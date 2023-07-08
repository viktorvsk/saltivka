# Contributing

Firstly, any help is appreciated, and Nostr welcomes as many participants as possible. Thank you for being here!

Secondly, there is a lot of work to be done for the relay implementation that goes beyond coding in general and Ruby in particular. If you want to contribute, there are various tasks that anyone can help with.

Currently, feel free to open an issue on GitHub for any questions, problems, or feature requests. We will find better ways to handle feedback if necessary in the future.

If you're unsure where to start, here are some examples of how you can contribute, which require different skills and interests:

* Ask questions if anything is unclear, including what this repository is about.
* If you spot any errors, mistakes, or uncertainties in the documentation or specifications, please open an issue.
* Use the `wss://saltivka.org` relay in your Nostr client if you are a regular user or a client developer.
* Deploy this relay instance on your server, whether it's for development, staging, or production, and share your feedback in the issues.
* Run the application in your local development setup without Docker and provide feedback in the issues.
* Report any bugs you find in the issues.
* Run tests with `rspec --format documentation` and review the output. There might be something important missing.
* In the output of the previous command, you will find yellow-colored specs. These scenarios should be covered with test cases. It's a great task to dive into Saltivka and Nostr!
* There are open issues that anyone can work on!

## Pull Requests

Please open pull requests against the `main` branch. Pay attention to the PR template and complete the necessary checks before submitting. 
Once your PR is merged into the `main` branch, it will automatically become part of the `viktorvsk/saltivka:latest` Docker image and part of the next tagged release.
Releases will be performed using Github Actions upon merging into `release-*` branches.