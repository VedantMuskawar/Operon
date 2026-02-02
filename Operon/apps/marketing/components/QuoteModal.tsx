"use client";

import { useState } from "react";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

interface QuoteModalProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
}

export function QuoteModal({ open, onOpenChange }: QuoteModalProps) {
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [phone, setPhone] = useState("");
  const [requirement, setRequirement] = useState("");

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    // Client-side only - no backend initially
    console.log({ name, email, phone, requirement });
    onOpenChange(false);
    setName("");
    setEmail("");
    setPhone("");
    setRequirement("");
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-[425px]">
        <DialogHeader>
          <DialogTitle>Request a Quote</DialogTitle>
          <DialogDescription>
            Fill in your details and we&apos;ll get back to you with a
            competitive quote for Fly Ash Bricks delivery.
          </DialogDescription>
        </DialogHeader>
        <form onSubmit={handleSubmit} className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="name">Name</Label>
            <Input
              id="name"
              placeholder="Your name"
              value={name}
              onChange={(e) => setName(e.target.value)}
              required
            />
          </div>
          <div className="space-y-2">
            <Label htmlFor="email">Email</Label>
            <Input
              id="email"
              type="email"
              placeholder="you@example.com"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
            />
          </div>
          <div className="space-y-2">
            <Label htmlFor="phone">Phone</Label>
            <Input
              id="phone"
              type="tel"
              placeholder="+91 98765 43210"
              value={phone}
              onChange={(e) => setPhone(e.target.value)}
              required
            />
          </div>
          <div className="space-y-2">
            <Label htmlFor="requirement">Quantity / Requirement</Label>
            <Input
              id="requirement"
              placeholder="e.g., 10,000 bricks for residential project"
              value={requirement}
              onChange={(e) => setRequirement(e.target.value)}
              required
            />
          </div>
          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
              Cancel
            </Button>
            <Button type="submit">Request Quote</Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
