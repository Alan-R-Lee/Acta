export class User {
  id: number;
  username: string;
  passwordHash: string;
  createdAt: number;
  email: string;
  displayName: string;

  constructor(
    id: number,
    username: string,
    passwordHash: string,
    createdAt: number = Date.now(),
    email: string = '',
    displayName: string = ''
  ) {
    this.id = id;
    this.username = username;
    this.passwordHash = passwordHash;
    this.createdAt = createdAt;
    this.email = email;
    this.displayName = displayName;
  }
}
