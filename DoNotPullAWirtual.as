void RenderMenuMain()
{
    string colorCode = "\\$0F7";
    string textPosition = "600";

    string text = "hello world";
	auto textSize = Draw::MeasureString(text);

	auto pos_orig = UI::GetCursorPos();
	UI::SetCursorPos(vec2(UI::GetWindowSize().x - textSize.x - Text::ParseInt(textPosition), pos_orig.y));
	UI::Text(text);
	UI::SetCursorPos(pos_orig);
}
