MAIN_BEGIN
MAIN_PANEL_BEGIN

  <div class="news_list"></div>

MAIN_PANEL_END

  <!-- ����������� ������ ������ ��������� -->
  <div style="display:none;" id="news_popup" class="fullscreen">
  <div class="fullscreen shade"></div>
  <!-- div class="i_popup" -->
  <form action="#" class="popup" id="news_form">
    <img class="close" src="img/x.png" onclick ="div_hide('news_popup')">
    <h2>����� ��������</h2>
    <hr class="wide">
    <input  name="id" type="hidden">
    <input  name="title" placeholder="���������" type="text">
    <textarea id="text" name="text" placeholder="�����"></textarea>
    <h4>��� �������:</h4>
    <select name="type">
      <option>1</option>
      <option>2</option>
      <option>3</option>
    </select>
    <a href="javascript:on_news_write()" class="submit_button">������������</a>
  </form>
  </div></div>

MAIN_END
