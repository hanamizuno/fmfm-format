///|
/// Calculate the n-th Fibonacci number (`fib(0) == 0`, `fib(1) == 1`).
///
/// ```mbt check
/// test {
///   inspect(@myapp.fib(10), content="55")
/// }
/// ```
pub fn fib(n : Int32) -> Int64 {
  for i = n, a = 0L, b = 1L; i > 0; i = i - 1, a = b, b = a + b {

  } nobreak {
    a
  }
}

///|
/// `data~` is a required labelled argument of type `Array[Int32]`.
/// `start~ : Int32 = 0` is a labelled argument with a default value.
/// `length?` is an optional labelled argument without a default; inside the
/// body it has type `Option[Int32]`.
pub fn sum(data~ : Array[Int32], start~ : Int32 = 0, length? : Int32) -> Int32 {
  let end = match length {
    Some(length) => start + length
    None => data.length()
  }
  for i = start, sum = 0; i < end; i = i + 1, sum = sum + data[i] {

  } nobreak {
    sum
  }
}
