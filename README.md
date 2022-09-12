## Discourse Calendar

Adds the ability to create a dynamic calendar in the first post of a topic.

Topic discussing the plugin itself can be found here: [https://meta.discourse.org/t/discourse-calendar/97376](https://meta.discourse.org/t/discourse-calendar/97376)

### Customisation

#### Plugins

##### Events

- `discourse_post_event_event_will_start` this DiscourseEvent will be triggered one hour before an event starts
- `discourse_post_event_event_started` this DiscourseEvent will be triggered when an event starts
- `discourse_post_event_event_ended` this DiscourseEvent will be triggered when an event ends

#### Custom Fields

Custom fields can be set in plugin settings. Once added a new form will appear on event UI.
These custom fields are available when a plugin event is triggered.

#### Holidays

See an incorrect or missing holiday? Familiarize yourself with the [holiday definition Syntax](vendor/holidays/definitions/doc/SYNTAX.md). Then make your updates in the `vendor/holiday/definitions` directory.

Generate updated holidays as follows.
```sh
cd vendor/holidays

# Generate holiday definitions
bundle exec rake generate:definitions
```

Install the plugin and switch to the discourse root(not the plugin directory).
```sh
# Collect all holiday regions into assets/javascripts/lib/regions.js
bundle exec rake javascript:update_constants
```
