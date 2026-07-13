class Chocolate {
  final int order;
  int row;
  int col;

  Chocolate(this.order, this.row, this.col);

  @override
  String toString() => 'Chocolate($order: $row,$col)';
}