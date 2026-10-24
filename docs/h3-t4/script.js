const opciones = document.querySelectorAll('#opciones button');
const errorTipo = document.getElementById('errorTipo');
const descripcion = document.getElementById('descripcion');
const contador = document.getElementById('contador');
const btnUbicacion = document.getElementById('btnUbicacion');
const estadoUbicacion = document.getElementById('estadoUbicacion');
const formulario = document.getElementById('formAlerta');
const mensaje = document.getElementById('mensaje');

let tipoSeleccionado = null;
let ubicacion = null;

opciones.forEach(boton => {
  boton.addEventListener('click', () => {
    opciones.forEach(b => b.setAttribute('aria-pressed', 'false'));
    boton.setAttribute('aria-pressed', 'true');
    tipoSeleccionado = boton.dataset.tipo;
    errorTipo.hidden = true;
  });
});

descripcion.addEventListener('input', () => {
  contador.textContent = `${descripcion.value.length}/200`;
});

btnUbicacion.addEventListener('click', () => {
  if (!('geolocation' in navigator)) {
    estadoUbicacion.textContent = 'Este navegador no permite obtener la ubicación.';
    return;
  }
  estadoUbicacion.textContent = 'Obteniendo ubicación…';
  navigator.geolocation.getCurrentPosition(
    pos => {
      ubicacion = { lat: pos.coords.latitude, lng: pos.coords.longitude };
      estadoUbicacion.textContent =
        `Ubicación lista: ${ubicacion.lat.toFixed(5)}, ${ubicacion.lng.toFixed(5)}`;
    },
    () => {
      ubicacion = null;
      estadoUbicacion.textContent =
        'No se pudo obtener la ubicación. Revisa los permisos del navegador.';
    },
    { enableHighAccuracy: true, timeout: 10000 }
  );
});

formulario.addEventListener('submit', e => {
  e.preventDefault();

  if (!tipoSeleccionado) {
    errorTipo.hidden = false;
    mensaje.hidden = true;
    return;
  }

  if (!ubicacion) {
    mensaje.hidden = false;
    mensaje.className = 'aviso';
    mensaje.textContent = 'Agrega tu ubicación antes de enviar.';
    return;
  }

  const anonima = document.getElementById('anonima').checked;
  mensaje.hidden = false;
  mensaje.className = 'exito';
  mensaje.textContent =
    `Alerta preparada: ${tipoSeleccionado}${anonima ? ' (anónima)' : ''}. ` +
    'Maqueta: aún no se envía al servidor.';

  opciones.forEach(b => b.setAttribute('aria-pressed', 'false'));
  tipoSeleccionado = null;
  ubicacion = null;
  descripcion.value = '';
  contador.textContent = '0/200';
  estadoUbicacion.textContent = 'Sin ubicación seleccionada.';
  document.getElementById('anonima').checked = false;
});
