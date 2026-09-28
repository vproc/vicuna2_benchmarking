module {
  func.func @vec_add_i8(%arg0: tensor<4xi8>, %arg1: tensor<4xi8>) -> tensor<4xi8> {
    %0 = arith.addi %arg0, %arg1 : tensor<4xi8>
    return %0 : tensor<4xi8>
  }
}