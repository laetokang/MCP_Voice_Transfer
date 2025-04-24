String postprocessText(String input) {
  return input
      .replaceAll(RegExp(r'[^\uAC00-\uD7A3a-zA-Z0-9\s]'), '') // 특수문자 제거
      .replaceAll(RegExp(r'\s+'), ' ') // 중복 공백 제거
      .trim(); // 앞뒤 공백 제거
}
