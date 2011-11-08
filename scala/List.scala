//
// An excercise to build a functional/immutable list.
//
// Note: The excercise was to observe the type signatures (not to be concerned with performance).
//

package steshaw.collection

sealed abstract class List[+A] {
  def ::[B >: A](b: B): List[B] = Cons(b, this)

  def length: Int =
    this match {
      case Nil => 0
      case Cons(head, tail) => 1 + tail.length
    }

  def append[B >: A](bs: List[B]): List[B] = this match {
    case Nil => bs
    case Cons(a, as) => Cons(a, as.append(bs))
  }
}
case class Cons[+A](head: A, tail: List[A]) extends List[A]
case object Nil extends List[Nothing]

object List {
  def flatten[A](xss: List[List[A]]): List[A] = xss match {
    case Nil => Nil
    case Cons(xs, xss) => append(xs, (flatten(xss)))
  }

  def length[A](xs: List[A]): Int =
    xs match {
      case Nil => 0
      case Cons(head, tail) => 1 + length(tail)
    }

  def append[A](as: List[A], bs: List[A]): List[A] = as match {
    case Nil => bs
    case Cons(a, as) => Cons(a, as.append(bs))
  }
}

object Demo {
  val as = Cons(1, Cons(2, Nil))
  val bs = Cons(3, Cons(4, Nil))
  val xxs = Cons(as, Cons(bs, Nil))
  val flat = List.flatten(xxs)
}
