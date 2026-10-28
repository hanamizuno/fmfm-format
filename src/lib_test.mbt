///|
test "fib" {
  let array = [1, 2, 3, 4, 5].map(@myapp.fib)

  // `inspect` / `debug_inspect` check the output of the function.
  // Just write `inspect(value)` (scalars) or `debug_inspect(value)`
  // (arrays, maps, tuples, ...) and execute `moon test --update`
  // to update the expected output, and verify them afterwards
  debug_inspect(array, content="[1, 1, 2, 3, 5]")
}

///|
test "sum" {
  let array = [1, 2, 3, 4, 5]
  inspect(@myapp.sum(data=array), content="15")
  inspect(@myapp.sum(data=array, start=1), content="14")
  inspect(@myapp.sum(data=array, length=3), content="6")
  let length = None
  // Use `?` for punning
  inspect(@myapp.sum(data=array, length?), content="15")
}
