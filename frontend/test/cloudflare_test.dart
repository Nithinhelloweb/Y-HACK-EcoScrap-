import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;

void main() {
  test("Cloudflare static endpoint connects successfully", () async {
    final response = await http.get(Uri.parse("https://ecoscrap.srishakthicgpa.in/api/health"));
    expect(response.statusCode, 200);
    expect(response.body.contains("healthy"), isTrue);
  });
}
