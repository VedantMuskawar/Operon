sealed class CallOverlayEvent {
  const CallOverlayEvent();
}

class PhoneNumberReceived extends CallOverlayEvent {
  const PhoneNumberReceived(this.phone);
  final String phone;
}
