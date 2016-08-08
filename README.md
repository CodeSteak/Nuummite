# Nuummite

Nuummite is very small embedded key-value store. All data is kept
in RAM (in a Crystal Hash) and is also written to disk.
So don't use Nuummite to handle big chunks of data.
Keys and Values are always Strings.
It just comes with the most basic operations.

NOTE: Nuummite is stil WIP.

## Installation


Add this to your application's `shard.yml`:

```yaml
dependencies:
  nuummite:
    github: codesteak/nuummite
```


## Usage

```crystal
require "nuummite"
```

#### Open the database
```crystal
db = Nuummite.new("path/to/folder", "optional-filename.db")
```

#### Put some values in
```crystal
db["hello"] = "world"
db["42"] = "Answer to the Ultimate Question of Life, The Universe, and Everything"
db["whitespace"] = "Hey\n\t\t :D"
```

#### Read values
```crystal
db["hello"]? # => "world"
db["ehhhh"]? # => nil
```

#### Delete
```crystal
db.delete "hello"
```

#### Clean
Since values are saved to disk in a log style file sizes grow.
Your key-value store needs a clean.
```crystal
db.clean
```
By default it autocleans after 10_000_000 writes.
To modify this behavior you can:
```crystal
db.autoclean_after_writes = 1000 # cleans after 1000 writes or deletes
db.autoclean_after_writes = nil  # does not autoclean
```

#### Shutdown
You can also shutdown nuummite by
```crystal
db.shutdown
```

That's all you need to know :smile:

## Contributing

1. Fork it ( https://github.com/codesteak/nuummite/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request

## Contributors

- [CodeSteak](https://github.com/CodeSteak) - creator, maintainer
