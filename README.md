# Export anime list

## About
Export seasonal anime list to csv with ruby program using anichart.net graphql API

## Requirements
- Ruby: MRI or JRuby

## Installation

Install activesupport gem:
```zsh
$ gem install activesupport
```

Install http gem:
```zsh
$ gem install http
```

## Documentation

### Basic Usage

```zsh
$ ruby export.rb --season SEASON --year YEAR
```
#### options:
- `--season`: Airing season [options: WINTER, SPRING, SUMMER, FALL]
- `--year`: Airing year (e.g: 2023)