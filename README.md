# m-bind-config

Configuração do Klipper da impressora M-BIND (IDEX, seringas). É a pasta
`~/printer_data/config` de cada máquina.

## O que é de todas as máquinas e o que é de cada uma

| Ficheiro | Onde vive |
|---|---|
| `mbind.cfg`, `hardware/`, `impressao/`, `calibracao/`, `desenvolvimento/` | no repositório (iguais em todas as máquinas) |
| `moonraker.conf`, `crowsnest.conf`, `KlipperScreen.conf`, `sonar.conf` | no repositório |
| `printer.cfg`: números de série das placas, PID, altura do Z | só na máquina (modelo: `printer.cfg.exemplo`) |
| `variables.cfg`: offsets do T1, estado e datas das calibrações | só na máquina |
| `ktamv_camera_matrix.json`: calibração da câmara | só na máquina |
| `mainsail.cfg`, `timelapse.cfg`, `usb_import.cfg` | criados pelos instaladores desses programas |

O `.gitignore` impede que os ficheiros de cada máquina vão para o repositório.

O `printer.cfg` inclui o `mbind.cfg` e tem os valores desta máquina. Os valores
calibrados ficam no `printer.cfg` porque o SAVE_CONFIG só consegue gravar o que
está nesse ficheiro.

## Máquina nova

1. Raspberry Pi OS Lite (64 bit), utilizador `blocks`.
2. Pelo KIAUH: Klipper, Moonraker, Mainsail, KlipperScreen e Crowsnest.
3. Firmware do Klipper gravado na Octopus Pro (STM32H723) e nas duas H36
   (STM32G431), com as três placas ligadas por USB.
4. Instalar a configuração:
   ```
   git clone https://github.com/lrmartins97/m-bind-config.git ~/m-bind-config
   bash ~/m-bind-config/instalar.sh
   ```
   O script:
   - encontra os números de série (pede para desligar e voltar a ligar o USB da
     cabeça T1, para distinguir o T0 do T1);
   - guarda a pasta config do KIAUH em `config_antes_<data>` e põe esta no lugar
     dela;
   - cria o `printer.cfg`;
   - instala o moonraker-timelapse, o Sonar, o NozzleSight e o
     print-from-usb-klipper.
5. Calibrar, pela ordem que o script mostra no fim: confirmar T0/T1, PID, Z,
   câmaras, foco da câmara e `CALIBRATE_IDEX`.

Se o repositório for privado, o `git clone` pede o utilizador e um token do
GitHub (não a password). O token não fica guardado na máquina.

## Atualizar uma máquina

```
cd ~/printer_data/config && git pull
sudo systemctl restart klipper
```

O `git pull` não toca no `printer.cfg` nem nos outros ficheiros de cada máquina.

## Alterar a configuração

As alterações fazem-se no repositório e chegam às máquinas pelo `git pull`.
Uma alteração feita à mão numa máquina aparece no `git status` dessa máquina.
Antes de fazer `git pull`, confirma que não há nada que se perca.
