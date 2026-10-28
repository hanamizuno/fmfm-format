# myuser/myapp

MoonBit template module.

## Package

- `myuser/myapp`

## Quick Example

```mbt check
///|
test {
  inspect(@myapp.fib(10), content="55")
  inspect(@myapp.sum(data=[1, 2, 3, 4, 5]), content="15")
}
```

## Included Examples

- Unit tests in `lib_test.mbt`
- Property-based tests in `quickcheck_test.mbt`
- Benchmarks in `lib_bench.mbt`

## Recommended Reading

- [MoonBit updates](https://www.moonbitlang.com/updates)
- [moonbitlang/quickcheck](https://github.com/moonbitlang/quickcheck)
