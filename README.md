# pasta
This script lets you easily manage your copypastas. These copypastas can be text or images which you need to move off or on your system clipboard.

# Why?
I wanted to really get familiar with bash. This project was inspired by [pass](https://www.passwordstore.org/) in terms of usage. However, it differs in that the data being saved is not intended to be secret, and copying and pasting images is supported in addition to text.

# Usage
## Getting started
```
pasta init [YOUR_PASTA_DIRECTORY]
```
This sets up the given directory to store your copypastas. If no directory is provided, it creates a `.pastas` folder in the home directory.

## Create new copypastas
```
# Save the data currently on the system clipboard as PASTA_NAME
pasta save PASTA_NAME

# Open the default text editor to write the copypasta
pasta insert PASTA_NAME

# Register the given file as a copypasta named PASTA_NAME
pasta file FILE PASTA_NAME
```

## Access copypastas
```
# Place copypastas on the system clipboard
pasta PASTA_NAME
pasta load PASTA_NAME

# Paste the given copypasta to a file
pasta paste PASTA_NAME FILE

# Inspect the copypasta (Outputted to terminal if text and opened with the system image viewer if an image)
pasta inspect PASTA_NAME
pasta show PASTA_NAME
```

## Search copypastas
```
# List the existing copypastas
pasta list [subfolder]
pasta ls [subfolder]

# Search copypastas by pasta name
pasta find PASTA_NAMES
pasta search PASTA_NAMES

# Search text copypastas for the given string
pasta grep SEARCH_STRING
```

## Manage copypastas
```
# Create a hard link of PASTA_1 called PASTA_2
pasta alias PASTA_1 PASTA_2
pasta ln PASTA_1 PASTA_2

# Create a copy of PASTA_1 and call it PASTA_2 (editing PASTA_1 does not affect PASTA_2)
pasta cp PASTA_1 PASTA_2

# Rename PASTA_1 to PASTA_2
pasta rename PASTA_1 PASTA_2
pasta mv PASTA_1 PASTA_2

# Delete the copypasta
pasta delete PASTA_NAME
pasta remove PASTA_NAME
pasta rm PASTA_NAME

# Edit an existing copypasta (Default editor if text, and ImageMagick if an image)
pasta edit PASTA_NAME
```

You can even organize your pastas into categories.
For instance, if you want to have an emoji category, you can use
emoji/thinking_face as your PASTA_NAME.


# Testing
This repo uses [BATS](https://github.com/bats-core/bats-core) for testing. To run all the tests, use
```
bats test
```

# Roadmap
- [X] `pasta save`
- [X] `pasta insert`
- [X] `pasta file`
- [ ] `pasta load`
- [ ] `pasta paste`
- [ ] `pasta show`
- [ ] `pasta list`
- [ ] `pasta find`
- [ ] `pasta grep`
- [ ] `pasta alias`
- [ ] `pasta cp`
- [ ] `pasta rename`
- [ ] `pasta delete`
- [ ] `pasta edit`
- [X] `pasta usage`
- [X] `pasta version`
- [ ] Support MacOS
- [ ] Bash completions
