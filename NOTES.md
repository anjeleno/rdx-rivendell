RE: 
/root/rdx-rivendell/config/rdx-profiles.xml
      <!-- Live microphone input -->
      <connection source="system:capture_1" dest="rivendell_0:record_0L"/>
      <connection source="system:capture_2" dest="rivendell_0:record_0R"/>
- While we do want to support diecrt input from an external source on the system, we also need to support audio cpature from VLC routed to Rivendell record. There should be reference to Jack routes from VLC out to Rivnedell in, in: /root/rdx-rivendell/rivendell-installer/APPS/configs/QjackCtl.conf