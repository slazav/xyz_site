MAIN_BEGIN
MAIN_PANEL_BEGIN

<script>
  function on_new() {
    div_show('form1')
  }
  function on_edit(id) {
  }
  function on_delete(id) {
  }
</script>

      <h3>��� ������ ���� ����� ��������</h3>
      <p>��������: <img src="img/edit.png" class="pointer"
         onclick="div_show('form1')" alt="�������� ����� ���������">

MAIN_PANEL_END

  <!-- ����������� ������ ������ ��������� -->
  <div style="display:none;" id="form1" class="fullscreen">
  <div class="fullscreen shade"></div>
  <!-- div class="i_popup" -->
  <form action="#" class="popup" id="form1" method="post" name="form">
    <img class="close" src="img/x.png" onclick ="div_hide('form1')">
    <h2>����� ��������</h2>
    <hr class="wide">
    <input id="title" name="title" placeholder="���������" type="text">
    <textarea id="text" name="text" placeholder="�����"></textarea>
    <p>��� �������:</p>
    <select id="type" name="type">
      <option>1</option>
      <option>2</option>
      <option>3</option>
    </select>
    <a href="javascript:%20publish('form1')" class="submit_button">������������</a>
  </form>
  </div></div>

MAIN_END
