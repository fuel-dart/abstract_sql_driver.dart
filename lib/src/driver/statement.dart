import "dart:async" show Future;
import "result.dart" show Result, ResultSet;

abstract class PreparedStatement {
  Future<void> close();
  void bind();
}
